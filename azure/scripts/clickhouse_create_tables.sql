-- 0. Database creation 
-- CREATE DATABASE IF NOT EXISTS {{ .Values.database }} ON CLUSTER '{{ include "clickhouse.clustername" . }}';

-- 1. Kafka engine table for metering data (LATEST as of 2025-07-25)
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.divyam_metering_data_kafka ON CLUSTER '{{ include "clickhouse.clustername" . }}'
(
    response_id String,
    timestamp DateTime64(9),
    org_id UInt32,
    svc_acct_id String,
    custom_tags String,
    requested_model String,
    requested_model_provider String,
    routed_model String,
    routed_model_provider String,
    router_traffic_bucket String,
    is_stream UInt8,
    response_status UInt16,
    chunk_count UInt32,
    ttft_ms UInt32,
    ttlt_ms UInt32,
    prompt_tokens UInt32,
    completion_tokens UInt32,
    total_tokens UInt32
) ENGINE = Kafka
SETTINGS 
    kafka_broker_list = '{{ .Values.kafka_integration.broker_list }}',
    kafka_topic_list = 'router-metering-logs',
    kafka_group_name = 'clickhouse_consumer_group',
    kafka_format = 'JSONEachRow';

-- 2. Replicated Table for metering data (ALTERs need to be run for new columns!)
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.divyam_metering_replicated ON CLUSTER '{{ include "clickhouse.clustername" . }}'
(
    response_id String,
    timestamp DateTime64,
    org_id UInt32,
    svc_acct_id String,
    custom_tags String,
    requested_model String,
    requested_model_provider String,
    routed_model String,
    routed_model_provider String,
    router_traffic_bucket String,
    is_stream UInt8,
    response_status UInt16,
    chunk_count UInt32,
    ttft_ms UInt32,
    ttlt_ms UInt32,
    prompt_tokens UInt32,
    completion_tokens UInt32,
    total_tokens UInt32,
    minute DateTime MATERIALIZED toStartOfMinute(timestamp)
) ENGINE = ReplicatedReplacingMergeTree('/clickhouse/tables/{shard}/{database}/divyam_metering_replicated_v1', '{replica}', timestamp)
PARTITION BY toYYYYMM(timestamp)
ORDER BY (org_id, svc_acct_id, response_id)
TTL toDateTime(timestamp) + INTERVAL 90 DAY;

-- 3. Materialized view for metering data (keep column order matching replicated table)
CREATE MATERIALIZED VIEW IF NOT EXISTS {{ .Values.database }}.divyam_metering_data_mv ON CLUSTER '{{ include "clickhouse.clustername" . }}'
TO {{ .Values.database }}.divyam_metering_replicated
AS
SELECT
    response_id,
    timestamp,
    org_id,
    svc_acct_id,
    custom_tags,
    requested_model,
    requested_model_provider,
    routed_model,
    routed_model_provider,
    router_traffic_bucket,
    is_stream,
    response_status,
    chunk_count,
    ttft_ms,
    ttlt_ms,
    prompt_tokens,
    completion_tokens,
    total_tokens
FROM {{ .Values.database }}.divyam_metering_data_kafka;

-- 4. Distributed Table for metering data
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.divyam_metering_data_dist ON CLUSTER '{{ include "clickhouse.clustername" . }}'
AS {{ .Values.database }}.divyam_metering_replicated 
ENGINE = Distributed('{{ include "clickhouse.clustername" . }}',
                    {{ .Values.database }},
                    divyam_metering_replicated,
                    rand());

-- 5. Kafka engine table for raw_logs (LATEST as of 2025-06-11)
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.kafka_raw_logs_topic ON CLUSTER '{{ include "clickhouse.clustername" . }}'
(
    response_id String,
    timestamp DateTime64(9),
    env String,
    org_id UInt32,
    svc_acct_id String,
    request_method String,
    request_path String,
    request_headers String,
    request_body String,
    request_body_translated String,
    request_auth_user_info String,
    response_status UInt16,
    response_headers String,
    response_body String,
    response_metering String,
    selection_context String,
    custom_tags String
)
ENGINE = Kafka()
SETTINGS
    kafka_broker_list = '{{ .Values.kafka_integration.broker_list }}',
    kafka_topic_list = 'router-raw-logs',
    kafka_group_name = 'clickhouse_consumer_group',
    kafka_format = 'JSONEachRow',
    kafka_num_consumers = 2;

-- 6. Replicated Table for raw_logs (ALTERs for selection_context/custom_tags must be run for upgrades!)
-- Make sure the same columns are added to shadow_raw_logs
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.raw_logs_replicated ON CLUSTER '{{ include "clickhouse.clustername" . }}'
(
    response_id String,
    timestamp DateTime64(9),
    env String,
    org_id UInt32,
    svc_acct_id String,
    request_method String,
    request_path String,
    request_headers String,
    request_body String,
    request_auth_user_info String,
    response_status UInt16,
    response_headers String,
    response_body String,
    request_body_translated String,
    response_metering String,
    selection_context String,
    custom_tags String
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/{database}/raw_logs_replicated_v1', '{replica}')
PARTITION BY toYYYYMM(timestamp)
ORDER BY (org_id, svc_acct_id, timestamp);

-- 7. Materialized View for raw_logs (latest columns)
CREATE MATERIALIZED VIEW IF NOT EXISTS {{ .Values.database }}.raw_logs_mv ON CLUSTER '{{ include "clickhouse.clustername" . }}'
TO {{ .Values.database }}.raw_logs_replicated
AS SELECT
    timestamp,
    env,
    org_id,
    svc_acct_id,
    request_method,
    request_path,
    request_headers,
    request_body,
    request_body_translated,
    request_auth_user_info,
    response_status,
    response_id,
    response_headers,
    response_body,        
    response_metering,
    selection_context,
    custom_tags
FROM {{ .Values.database }}.kafka_raw_logs_topic;

-- 8. Distributed Table for raw_logs
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.raw_logs_dist ON CLUSTER '{{ include "clickhouse.clustername" . }}'
AS {{ .Values.database }}.raw_logs_replicated
ENGINE = Distributed('{{ include "clickhouse.clustername" . }}',
                    {{ .Values.database }},
                    raw_logs_replicated,
                    rand());

-- 9. Mysql Engine table for dim_org_mysql
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.dim_org_mysql ON CLUSTER '{{ include "clickhouse.clustername" . }}'
(
    id UInt32,
    name String
) ENGINE = MySQL('{{ .Values.mysql_integration.host }}', '{{ .Values.mysql_integration.source_database }}', 'orgs', '{{ .Values.mysql_integration.username }}', '{{ .Values.mysql_integration.password }}');

-- 10. Mysql Engine table for dim_svc_acct_mysql
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.dim_svc_acct_mysql ON CLUSTER '{{ include "clickhouse.clustername" . }}'
(
    id String,
    name String,
    org_id UInt32
) ENGINE = MySQL('{{ .Values.mysql_integration.host }}', '{{ .Values.mysql_integration.source_database }}', 'service_accounts', '{{ .Values.mysql_integration.username }}', '{{ .Values.mysql_integration.password }}');

-- 11. Table for Model Rate Cards
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.model_rate_cards_replicated ON CLUSTER '{{ include "clickhouse.clustername" . }}'
(
    `provider`           String,
    `model`              String,
    `currency`           String,
    `input_token_rate`   Float32,
    `output_token_rate`  Float32,
    `per_n_tokens`       Decimal(24, 6),
    `update_timestamp`   DateTime64
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/{database}/model_rate_cards_v1', '{replica}')
ORDER BY (provider, model);

-- 12. Table for Model Rate Cards
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.model_rate_cards_dist ON CLUSTER '{{ include "clickhouse.clustername" . }}'
AS {{ .Values.database }}.model_rate_cards_replicated
ENGINE = Distributed('{{ include "clickhouse.clustername" . }}',
                    {{ .Values.database }},
                    model_rate_cards_replicated,
                    rand());

-- 13. Model Selector Training Performance Table
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.model_selector_training_perf_replicated ON CLUSTER '{{ include "clickhouse.clustername" . }}'
(
    `model_selector_version_id` Int32,
    `org_id` Int32,
    `service_account_id` String,
    `lambda` Float64,
    `accuracy_improvement` Float64,
    `cost_savings` Float64,
    `router_accuracy` Float64,
    `router_cost` Float64,
    `model_distribution` String,           -- JSON string
    `best_model_accuracy` Float64,
    `best_model_cost` Float64,
    `best_model` String,
    `created_at` DateTime64
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/{database}/model_selector_training_perf_v1', '{replica}')
PARTITION BY toYYYYMM(created_at)
ORDER BY (org_id, service_account_id, model_selector_version_id);

CREATE TABLE IF NOT EXISTS {{ .Values.database }}.model_selector_training_perf_dist ON CLUSTER '{{ include "clickhouse.clustername" . }}'
AS {{ .Values.database }}.model_selector_training_perf_replicated
ENGINE = Distributed('{{ include "clickhouse.clustername" . }}',
                    {{ .Values.database }},
                    model_selector_training_perf_replicated,
                    rand());

-- 14. Table for Evaluation Metrics
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.evaluation_metrics_replicated ON CLUSTER '{{ include "clickhouse.clustername" . }}'
(
    `org_id` Int32 DEFAULT 0,
    `svc_acct_id` String DEFAULT '',
    `eval_granularity` String DEFAULT 'LLM_REQUEST_RESPONSE',
    `id` String DEFAULT '',
    `timestamp` DateTime DEFAULT now(),
    `traffic_bucket` String DEFAULT '',
    `is_shadow` UInt8 DEFAULT 0,
    `total_requests` Int32 DEFAULT 0,
    `total_prompt_tokens` Int32 DEFAULT 0,
    `total_completion_tokens` Int32 DEFAULT 0,
    `total_tokens` Int32 DEFAULT 0,
    `total_ttft_ms` Int32 DEFAULT 0,
    `total_ttlt_ms` Int32 DEFAULT 0,
    `eval_id` Int32 DEFAULT 0,
    `eval_score` Float64 DEFAULT 0.0,
    `requested_models_cost` Float64 DEFAULT 0.0,
    `selected_models_cost` Float64 DEFAULT 0.0,
    `model_selection_override_requests_count` Int32 DEFAULT 0,
    `cost_savings` Float64 DEFAULT 0.0
)
ENGINE = ReplicatedReplacingMergeTree('/clickhouse/tables/{shard}/{database}/evaluation_metrics_v1', '{replica}', timestamp)
PARTITION BY toYYYYMM(timestamp)
ORDER BY (org_id, svc_acct_id, id);

CREATE TABLE IF NOT EXISTS {{ .Values.database }}.evaluation_metrics_dist ON CLUSTER '{{ include "clickhouse.clustername" . }}'
AS {{ .Values.database }}.evaluation_metrics_replicated
ENGINE = Distributed('{{ include "clickhouse.clustername" . }}',
                    {{ .Values.database }},
                    evaluation_metrics_replicated,
                    rand());

-- 15. Table for Eval Job Last Run
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.eval_job_last_run_replicated  ON CLUSTER '{{ include "clickhouse.clustername" . }}' 
(
            job_name String,
            end_time DateTime,
            updated_at DateTime
            )
            ENGINE = ReplicatedReplacingMergeTree(
            '/clickhouse/tables/{shard}/{database}/eval_job_last_run_v1',
            '{replica}',
            updated_at)
            PARTITION BY job_name
            ORDER BY (job_name);

CREATE TABLE IF NOT EXISTS {{ .Values.database }}.eval_job_last_run_dist ON CLUSTER '{{ include "clickhouse.clustername" . }}'
AS {{ .Values.database }}.eval_job_last_run_replicated
ENGINE = Distributed('{{ include "clickhouse.clustername" . }}',
                    {{ .Values.database }},
                    eval_job_last_run_replicated,
                    rand());

-- 16. Replicated Table for shadow_raw_logs (ALTERs for selection_context/custom_tags must be run for upgrades!)
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.shadow_raw_logs_replicated ON CLUSTER '{{ include "clickhouse.clustername" . }}'
AS {{ .Values.database }}.raw_logs_replicated 
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/{database}/shadow_raw_logs_replicated_v1', '{replica}')
PARTITION BY toYYYYMM(timestamp)
ORDER BY (org_id, svc_acct_id, timestamp);

-- 17. Distributed Table for shadow_raw_logs
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.shadow_raw_logs_dist ON CLUSTER '{{ include "clickhouse.clustername" . }}'
AS {{ .Values.database }}.shadow_raw_logs_replicated
ENGINE = Distributed('{{ include "clickhouse.clustername" . }}',
                    {{ .Values.database }},
                    shadow_raw_logs_replicated,
                    rand())

-- 18. Table for Cost Metrics
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.cost_metrics_replicated ON CLUSTER '{{ include "clickhouse.clustername" . }}'
(
    `org_id` Int32 DEFAULT 0,
    `svc_acct_id` String DEFAULT '',
    `id` String DEFAULT '',
    `timestamp` DateTime DEFAULT now(),
    `traffic_bucket` String DEFAULT '',
    `is_shadow` UInt8 DEFAULT 0,
    `total_requests` Int32 DEFAULT 0,
    `total_prompt_tokens` Int32 DEFAULT 0,
    `total_completion_tokens` Int32 DEFAULT 0,
    `total_tokens` Int32 DEFAULT 0,
    `total_ttft_ms` Int32 DEFAULT 0,
    `total_ttlt_ms` Int32 DEFAULT 0,
    `requested_models_cost` Float64 DEFAULT 0.0,
    `selected_models_cost` Float64 DEFAULT 0.0,
    `cost_savings` Float64 DEFAULT 0.0,
    `model_selection_override_requests_count` Int32 DEFAULT 0
)
ENGINE = ReplicatedReplacingMergeTree('/clickhouse/tables/{shard}/{database}/cost_metrics_v1', '{replica}', timestamp)
PARTITION BY toYYYYMM(timestamp)
ORDER BY (org_id, svc_acct_id, id);

CREATE TABLE IF NOT EXISTS {{ .Values.database }}.cost_metrics_dist ON CLUSTER '{{ include "clickhouse.clustername" . }}'
AS {{ .Values.database }}.cost_metrics_replicated
ENGINE = Distributed('{{ include "clickhouse.clustername" . }}',
                    {{ .Values.database }},
                    cost_metrics_replicated,
                    rand());


-- 19. New Table for multiple Evaluation Metrics
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.quality_scores_replicated ON CLUSTER '{{ include "clickhouse.clustername" . }}'
(
    `org_id` Int32 DEFAULT 0,
    `svc_acct_id` String DEFAULT '',
    `eval_granularity` String DEFAULT 'LLM_REQUEST_RESPONSE',
    `id` String DEFAULT '',
    `timestamp` DateTime DEFAULT now(),
    `traffic_bucket` String DEFAULT '',
    `is_shadow` UInt8 DEFAULT 0,
    `total_requests` Int32 DEFAULT 0,
    `model_selection_override_requests_count` Int32 DEFAULT 0,
    `eval_id` Int32 DEFAULT 0,
    `eval_score` Float64 DEFAULT 0.0
)
ENGINE = ReplicatedReplacingMergeTree('/clickhouse/tables/{shard}/{database}/quality_scores_v1', '{replica}', timestamp)
PARTITION BY toYYYYMM(timestamp)
ORDER BY (org_id, svc_acct_id, eval_id, id);

CREATE TABLE IF NOT EXISTS {{ .Values.database }}.quality_scores_dist ON CLUSTER '{{ include "clickhouse.clustername" . }}'
AS {{ .Values.database }}.quality_scores_replicated
ENGINE = Distributed('{{ include "clickhouse.clustername" . }}',
                    {{ .Values.database }},
                    quality_scores_replicated,
                    rand());
