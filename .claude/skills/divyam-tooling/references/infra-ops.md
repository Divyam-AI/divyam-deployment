# Divyam infra operations (datastores & pipeline) — SRE reference

Cluster-maintenance playbook for the Divyam stateful/infra components: **health checks, data-flow
debugging, alerts (P0/P1), and deploy/scale ops**. Pairs with `debugging.md` (helm/release failures),
`kubectl.md`, `helm-helmfile.md`, `known-gotchas.md`. The **developer** half (knobs, schema/table
conventions, dos & don'ts) lives in the `divyam-sandbox` harness `infra-<x>` skills — this file is the
**operator** half the `divyam-sre` agent uses.

> **Known instabilities** are tracked centrally in the `divyam-sandbox` harness
> `docs/architecture/known-gaps.md` (by ID, e.g. `G-MYSQL-HA`, `G-OTEL-BUFFER`). Reference those IDs
> here rather than re-describing — keep this file drift-free.

Conventions: kubeconfig first (`make k8s -- kubeconfig`). Namespaces `<chart>-<env>-ns`; releases
`<chart>-<env>`. Scale/resources are set in the **k8s-values `resources.yaml`** the helmfile reads, then
`make k8s -- upgrade -l <chart> -d <values-dir>` (diff first). Alerts are defined in
`iac/2-app/2-alerts/common/rules/*.json` → only `CRITICAL` notifies Zenduty.

---

## ClickHouse  (analytics/OLAP · billing- & training-critical · Altinity operator)
Cluster `clk-<env>` (CHI + keeper CHK) in `clickhouse-<env>-ns`; svc `clk-<env>-service` (HTTP 8123,
native 9000); keeper 2181/9444. Ingests from Kafka (`router-raw-logs`, `router-metering-logs`) via
Kafka-engine tables (consumer group `clickhouse_consumer_group`, 5 consumers).

### Health
```bash
kubectl get pods -n clickhouse-<env>-ns                 # CHI + keeper pods Ready
kubectl get chi,chk -n clickhouse-<env>-ns              # Altinity CRs Completed/Reconciled
make k8s -- status | grep clickhouse                    # release deployed
clickhouse-client -q "SELECT database,table,is_readonly,absolute_delay,queue_size FROM system.replicas"
clickhouse-client -q "SELECT * FROM system.kafka"       # Kafka-engine consumers attached?
```

### Data-flow debugging (is telemetry landing?)
```bash
clickhouse-client -q "SELECT max(timestamp) FROM divyam_router_logs.raw_logs_dist"        # recent?
clickhouse-client -q "SELECT max(timestamp) FROM divyam_router_logs.divyam_metering_data_dist"
# lag rising but no rows → check Kafka side (see Kafka section) + that the MV/Kafka table exist
clickhouse-client -q "SELECT count() FROM system.merges"   # merge backlog
df -h (in pod) / kubectl describe pvc -n clickhouse-<env>-ns   # disk
```

### P0 (page) / P1 (warn)
- **P0:** Kafka-engine ingestion stalled / consumer lag growing (→ billing+training blocked); keeper
  quorum lost (writes/DDL fail); replica `is_readonly=1`; disk ≥ ~85% / `MergeTreePartsToThrowInsert`.
- **P1:** merge backlog rising, replication `queue_size`/`absolute_delay` growing, query latency,
  MV/insert errors, memory pressure. (Metrics via 8123 / managed-Prometheus; alerts in `2-alerts`.)

### Runbooks
- **Ingestion stalled:** 1) ClickHouse pod logs for consumer errors; 2) `SELECT * FROM system.kafka`
  (table attached? MV present? a recent `db-upgrades` may have detached it → recreate); 3) check Kafka
  health (under-ISR/offline); 4) check parts/disk. Restore in that order.
- **Keeper quorum lost:** check CHK pods; restore the keeper StatefulSet — replicas are read-only until
  quorum returns. Keep keeper count **odd**.
- **Read-only replica:** check keeper connectivity + ZK path; `SYSTEM RESTART REPLICA db.table`.
- **Disk full:** confirm TTL applied; `OPTIMIZE`/drop old parts; **expand PVC** (`persistence.size`) →
  `make k8s -- upgrade -l clickhouse`.

### Deploy / scale ops
- Scale: edit k8s-values `resources.yaml` (replicas/cpu/mem/storage) → `make k8s -- diff` →
  `upgrade -l clickhouse`. Resharding (`shardsCount`) is heavy — plan data redistribution.
- Upgrade: bump the Altinity image tag; the operator rolls. Test `db-upgrades` against the new server
  first. Back up before destructive ops.
- Capacity/gaps: keeper single-replica in some envs (no HA) — **(confirm per env)**.

---

## Kafka (Strimzi/KRaft)  (async telemetry transport · off request path)
Cluster `kafka-<env>-cluster` in `kafka-<env>-ns`; bootstrap `kafka-<env>-cluster-kafka-bootstrap…:9092`.
Producers: OTEL. Consumers: ClickHouse Kafka-engine (group `clickhouse_consumer_group`) + kafka-connect.

### Health / data-flow
```bash
kubectl get kafka,kafkanodepool,kafkatopic -n kafka-<env>-ns      # Strimzi CRs Ready
kubectl get pods -n kafka-<env>-ns | grep -vE 'Running|Completed'
# in a broker pod: topic end-offsets growing? consumer-group lag?
bin/kafka-consumer-groups.sh --bootstrap-server :9092 --describe --group clickhouse_consumer_group
```
### P0 / P1
- **P0:** `UnderMinIsrPartitionCount>0` / `OfflinePartitionsCount>0` (producers blocked → OTEL buffers →
  loss); active-controller≠1 (KRaft quorum); broker log-dir/disk full.
- **P1:** consumer lag rising, under-replicated partitions, frequent leader elections, produce latency.
  (JMX→Prometheus :9404; alerts in `2-alerts`.)
### Runbooks
- **Under-ISR/offline:** recover the down broker (`kubectl get pods`); **never delete broker PVCs**; ISR
  self-heals on rejoin. **Disk full:** enforce retention / expand PVC → `make k8s -- upgrade -l kafka-cluster`.
  **Controller quorum:** check KRaft controller pods. **Connect DLQ growing:** check connector + cloud creds/WIF.
### Deploy / scale
- k8s-values `resources.yaml`: broker replicas / storage / cpu-mem; topic partitions (raise with
  ClickHouse `kafka_num_consumers`). Keep rf=3 / min.isr=2. Rolling upgrade via Strimzi — never force-delete.

---

## OTEL Collector  (telemetry ingress · billing-critical on buffer overflow)
`otel-collector-<env>-ns`; metrics :8181, healthz :13133. Router → OTLP :4617/:4618 → routing → Kafka.

### Health / data-flow
```bash
kubectl get pods -n otel-collector-<env>-ns
curl -s <otel-svc>:13133/healthz
curl -s <otel-svc>:8181/metrics | grep -E 'otelcol_exporter_(sent|send_failed)|otelcol_exporter_queue'
```
### P0 / P1
- **P0:** collector down (router can't ship telemetry); `file_storage` disk near full while Kafka is
  down (imminent **data loss**); `memory_limiter` refusing (`otelcol_processor_refused_*`).
- **P1:** Kafka export retries/`send_failed`, `otelcol_exporter_queue_size`→`_capacity`, receiver refused.
### Runbooks
- **Down:** restart; check OOM (raise memory / `memory_limiter`). Router serving unaffected; telemetry
  resumes from the disk buffer. **Export failing:** fix Kafka first; the buffer drains on recovery —
  **act before the 10Gi `file_storage` fills**. **Buffer full:** restore Kafka / expand the PVC.
### Deploy / scale
- k8s-values `resources.yaml`: replicas, memory (+`memory_limiter.limit_mib`), `file_storage` size.
  Keep `producer.max_message_bytes` == Kafka `message.max.bytes` (268MB).

---

## Qdrant  (vector store · serving-relevant when a selector is live)
`qdrant-<env>-ns`; svc `qdrant-<env>-svc` (6333 http / 6334 grpc); `/metrics` on 6333.

### Health / data-flow
```bash
kubectl get pods -n qdrant-<env>-ns                     # qdrant-<env>-sts Ready
curl -s <qdrant-svc>:6333/healthz ; curl -s <qdrant-svc>:6333/collections   # collection per selector_id, status green
```
### P0 / P1
- **P0:** Qdrant down (selector inference fails for live selectors — confirm router fallback), disk full,
  a live selector's collection red/missing. **P1:** search-latency P95, memory near limit (HNSW OOM risk).
### Runbooks
- **Down:** restart (`qdrant-<env>-sts`); check PVC + node memory. **Collection missing/corrupt:**
  re-promote the selector (selector-training writes embeddings); restore from snapshot only if enabled.
  **Disk full:** expand PVC; clean inactive selectors' collections (training cleans — verify it ran).
### Deploy / scale
- k8s-values `resources.yaml`: **memory first** (HNSW is RAM-resident), storage, replicas/cluster (heavier).

---

## Redis  (offline cache for training/eval · NOT serving-critical)
`redis-<env>` Deployment; svc `redis-<env>-service` :6379. Standalone, AOF. **No metrics exporter (gap).**

### Health
```bash
kubectl get pods -n <redis-ns> ; kubectl exec <redis-pod> -- redis-cli ping
kubectl exec <redis-pod> -- redis-cli info memory   # used_memory vs maxmemory, evictions
```
### P0 / P1
- **P0:** low (offline). Closest: AOF disk full (bounded to training/eval, not serving).
- **P1:** Redis down → selector-training/evaluator re-call LLMs (**cost spike**); memory near `maxmemory`
  / high eviction (low hit-rate → cost). No exporter → use the training/eval LLM-cost signal as a proxy.
### Runbooks
- **Down:** restart — cache rebuilds on misses (no data loss; no serving impact). **Memory/evictions:**
  set/raise `maxmemory` + eviction policy. **AOF disk full:** expand PVC, or disable AOF (confirm).
### Deploy / scale
- k8s-values `resources.yaml`: memory + `maxmemory` + eviction (`allkeys-lru`), storage. HA not wired.

---

## MySQL  (router metadata DB · serving-critical · single-node SPOF)
`mysql-<env>-ns`; svc `mysql-<env>-svc` :3306; DB `divyam-<env>`; creds via external-secrets
(`mysql-<env>-credentials`). Datadog monitoring user bootstrapped via a Job.

### Health / data-flow
```bash
kubectl get pods -n mysql-<env>-ns                      # mysql-<env>-sts Ready
mysql -h mysql-<env>-svc -uroot -p -e "SELECT 1; SHOW STATUS LIKE 'Threads_connected'; SHOW VARIABLES LIKE 'max_connections';"
```
### P0 / P1
- **P0:** MySQL down (router serves cached keys via stale-while-error, but **new lookups + all writes
  fail**; training/cli blocked); disk full; connections exhausted ("Too many connections").
- **P1:** slow queries, long-running locks/transactions, buffer-pool pressure. (Datadog MySQL check; no
  mysqld_exporter — gap.)
### Runbooks
- **Down:** restart `mysql-<env>-sts`; check PVC. **No failover (single node)** — restore the pod/PVC;
  communicate that new onboarding/lookups are impacted until restored. **Disk full:** expand PVC + prune.
  **Too many connections:** find the source (router pool / runaway client); raise `max_connections` as a
  stopgap. **SQLAlchemy attribute error:** apply the additive migration FIRST, then restart (libs rule).
### Deploy / scale
- k8s-values `resources.yaml`: cpu/mem (buffer pool), storage, `max_connections`. **Back up before any
  upgrade (single node).** **Reliability gap: no replication/failover for a serving-critical store —
  candidate for an HA change.**
