# Alert Priority Matrix

| Metric | P0 Threshold | P1 Threshold | P2 Threshold | P3 Threshold |
|---|---|---|---|---|
| Router availability | 5xx rate > 20% OR service unavailable for 5 min |  |  |  |
| Router latency (p99) | > request timeout OR widespread timeouts | > 2–3x baseline for 10 min | Slight regression from baseline |  |
| Route selector availability |  | Fallback mode active OR selector unavailable | Elevated fallback usage (>25%) |  |
| Route selection quality - model selection | | Consistently selecting retired or degraded model | | |
| Route selection quality - cost signals | | Cost-per-request spike >X% over baseline for 15 min | | |
| Route selection quality - quality drift | | | Quality score distribution shift OR minor routing skew | || Kafka message drops | Any message loss OR retention exceeded |  |  |  |
| Kafka consumer lag |  | Lag exceeds SLA for 10 min | Lag growing steadily |  |
| ClickHouse ingestion | No rows ingested for 5 min | Ingestion delay exceeds SLA | Minor ingestion slowdown |  |
| ClickHouse write failures | Any insert/write failure |  |  |  |
| OTel collector export failures | Sustained telemetry loss with unrecoverable drops | Export failure rate > threshold | Partial telemetry gaps |  |
| Billing data mismatch | Missing billed records OR billing gaps detected | Delayed billing data OR per-model cost attribution is broken | Minor reconciliation mismatch |  |
| Superset dashboard availability |  |  | Dashboard unavailable |  |
| Dashboard freshness |  |  | Data stale beyond SLA |  |
| Metrics/logging visibility |  | No metrics/logs/traces across system | Partial telemetry missing |  |
| GCS archival pipeline |  | Irrecoverable archival data loss | Archival pipeline stopped OR backlog growing | Minor archival delay |
| Kafka disk usage | Disk full OR write failures | > 90% utilization | > 80% utilization | > 70% utilization |
| ClickHouse disk usage | Disk full OR inserts failing | > 90% utilization | > 80% utilization | > 70% utilization |
| OTel storage/buffer usage | Buffer exhaustion OR drops occurring | > 90% utilization | > 80% utilization | > 70% utilization |
| Storage growth rate | Sudden exhaustion risk (< 6h remaining capacity) | Rapid growth trend | Moderate growth trend |  |
| End-to-end pipeline health | Data permanently lost in pipeline | Pipeline delayed beyond SLA | Temporary backlog |  |
| Monitoring pipeline health |  | Fully blind observability system | Partial monitoring outage |  |
| EvalMate judge availability | | Judge unavailable OR producing no scores for 10 min | Judge latency elevated OR score freshness exceeds SLA | |
| Eval batch pipeline | | Batch not run beyond SLA | Batch delayed but recovering | Batch slower than expected |
| Model leaderboard freshness | | Rankings frozen beyond SLA | Rankings lagging | |
| Agent context retrieval | | Failure rate > threshold causing context-free fallback | Elevated retrieval errors | |
| Routing decision log availability | | No routing decisions logged for 10 min | Partial logging gaps | |
| New model eval pipeline | | | Pipeline stopped OR not picking up new models | Evaluation delayed |
| Per-model cost attribution | | Model attribution missing on >X% of billed requests | Minor attribution gaps | |Sonnet 4.6 Low

## Priority Definitions

| Priority | Meaning | Response Expectation |
|---|---|---|
| P0 | User impact OR irreversible data/revenue loss | Immediate response, paging required |
| P1 | Major degradation OR high near-term risk | Urgent investigation |
| P2 | Recoverable degradation OR operational issue | Same-day action |
| P3 | Informational OR capacity planning | Track and schedule remediation |

## Notes

- Prefer SLO-based alerts over raw infrastructure alerts.
- Distinguish carefully between:
  - Data delay (usually P1/P2)
  - Data loss (usually P0)
- Storage alerts should consider both:
  - Current utilization
  - Growth velocity / time-to-exhaustion
- Billing-impacting failures should be treated as revenue-critical.
