--------------------------------- DATABASE CREATION AND VERSIONING ---------------------------------
CREATE DATABASE IF NOT EXISTS {{ .Values.database }} ON CLUSTER '{{ .Values.clickhouse.clustername }}';
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.divyam_version_info ON CLUSTER '{{ .Values.clickhouse.clustername }}'
(
    version String,
    timestamp DateTime64(9)
) ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/{database}/divyam_version_info_v1', '{replica}')
ORDER BY (version);

--------------------------------- MYSQL ENGINE TABLES ---------------------------------
-- MySQL Engine table for dim_org_mysql
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.dim_org_mysql ON CLUSTER '{{ .Values.clickhouse.clustername }}'
(
    id UInt32,
    name String
) ENGINE = MySQL('{{ .Values.mysql_integration.host }}', '{{ .Values.mysql_integration.source_database }}', 'orgs', '{{ .Values.mysql_integration.username }}', '{{ .Values.mysql_integration.password }}');

-- MySQL Engine table for dim_svc_acct_mysql
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.dim_svc_acct_mysql ON CLUSTER '{{ .Values.clickhouse.clustername }}'
(
    id String,
    name String,
    org_id UInt32
) ENGINE = MySQL('{{ .Values.mysql_integration.host }}', '{{ .Values.mysql_integration.source_database }}', 'service_accounts', '{{ .Values.mysql_integration.username }}', '{{ .Values.mysql_integration.password }}');

-- MySQL Engine table for dim_models_mysql
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.dim_models_mysql ON CLUSTER '{{ .Values.clickhouse.clustername }}'
(
    `id` Int32,
    `name` String
) ENGINE = MySQL('{{ .Values.mysql_integration.host }}', '{{ .Values.mysql_integration.source_database }}', 'models', '{{ .Values.mysql_integration.username }}', '{{ .Values.mysql_integration.password }}');

-- MySQL Engine table for dim_model_providers_mysql
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.dim_model_providers_mysql ON CLUSTER '{{ .Values.clickhouse.clustername }}'
(
    `id` Int32,
    `name` String
) ENGINE = MySQL('{{ .Values.mysql_integration.host }}', '{{ .Values.mysql_integration.source_database }}', 'model_providers', '{{ .Values.mysql_integration.username }}', '{{ .Values.mysql_integration.password }}');

-- MySQL Engine table for dim_evals_mysql
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.dim_evals_mysql ON CLUSTER '{{ .Values.clickhouse.clustername }}'
(
    `id` Int32,
    `name` String
) ENGINE = MySQL('{{ .Values.mysql_integration.host }}', '{{ .Values.mysql_integration.source_database }}', 'evals', '{{ .Values.mysql_integration.username }}', '{{ .Values.mysql_integration.password }}');


-- MySQL Engine table for dim_mpi_mysql
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.dim_mpi_mysql ON CLUSTER '{{ .Values.clickhouse.clustername }}'
( 
`id` Int32, `org_id` Int32, 
`service_account_id` String, 
`provider_id` Int32, 
`model_id` Int32, 
`encrypted_model_api_key` String, 
`endpoint` String, 
`model_configs` String, 
`supported_modalities` String, 
`text_input_price` Float32, 
`text_output_price` Float32, 
`currency` String, 
`per_n_tokens` Int32, 
`is_active` UInt8, 
`is_selection_enabled` UInt8 
)
ENGINE = MySQL('{{ .Values.mysql_integration.host }}', '{{ .Values.mysql_integration.source_database }}', 'model_provider_info', '{{ .Values.mysql_integration.username }}', '{{ .Values.mysql_integration.password }}');

-- MySQL View for dim_model_rate_card_mysql_view
CREATE VIEW IF NOT EXISTS {{ .Values.database }}.dim_model_rate_card_mysql_view
ON CLUSTER '{{ .Values.clickhouse.clustername }}' AS
SELECT
    provider.name AS provider,
    model.name AS model,
    mpi.currency AS currency,
    CAST(mpi.text_input_price AS Decimal(6,3)) AS input_token_rate,
    CAST(mpi.text_output_price AS Decimal(6,3)) AS output_token_rate,
    mpi.per_n_tokens AS per_n_tokens
FROM {{ .Values.database }}.dim_mpi_mysql AS mpi
JOIN {{ .Values.database }}.dim_model_providers_mysql AS provider
    ON mpi.provider_id = provider.id
JOIN {{ .Values.database }}.dim_models_mysql AS model
    ON mpi.model_id = model.id;



--------------------------------- KAFKA ENGINE TABLES ---------------------------------
-- Kafka engine table for divyam_metering_data_kafka
-- NOTE: Any change to this table, should be altered in the replicated, distributed and materialized view as well.
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.divyam_metering_data_kafka ON CLUSTER '{{ .Values.clickhouse.clustername }}'
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

-- Replicated Table for divyam_metering_replicated
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.divyam_metering_replicated ON CLUSTER '{{ .Values.clickhouse.clustername }}'
AS {{ .Values.database }}.divyam_metering_data_kafka
ENGINE = ReplicatedReplacingMergeTree('/clickhouse/tables/{shard}/{database}/divyam_metering_replicated_v1', '{replica}', timestamp)
PARTITION BY (toYYYYMMDD(timestamp), org_id, svc_acct_id)
ORDER BY response_id
TTL toDateTime(timestamp) + INTERVAL {{ .Values.metrics_ttl_days }} DAY;

-- Materialized view for divyam_metering_data_mv
CREATE MATERIALIZED VIEW IF NOT EXISTS {{ .Values.database }}.divyam_metering_data_mv ON CLUSTER '{{ .Values.clickhouse.clustername }}'
TO {{ .Values.database }}.divyam_metering_replicated
AS SELECT * FROM {{ .Values.database }}.divyam_metering_data_kafka;

-- Distributed Table for divyam_metering_data_dist
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.divyam_metering_data_dist ON CLUSTER '{{ .Values.clickhouse.clustername }}'
AS {{ .Values.database }}.divyam_metering_data_kafka
ENGINE = Distributed('{{ .Values.clickhouse.clustername }}', {{ .Values.database }}, divyam_metering_data_kafka, rand());

-- Kafka engine table for kafka_raw_logs_topic
-- NOTE: Any change to this table, should be altered in the replicated, distributed and materialized view as well.
-- NOTE: Make sure the same columns are added to the corresponding shadow_raw_logs tables.
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.kafka_raw_logs_topic ON CLUSTER '{{ .Values.clickhouse.clustername }}'
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

-- Replicated Table for raw_logs_replicated
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.raw_logs_replicated ON CLUSTER '{{ .Values.clickhouse.clustername }}'
AS {{ .Values.database }}.kafka_raw_logs_topic
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/{database}/raw_logs_replicated_v1', '{replica}')
PARTITION BY (toYYYYMMDD(timestamp), org_id, svc_acct_id)
ORDER BY (org_id, svc_acct_id, timestamp)
TTL toDateTime(timestamp) + INTERVAL {{ .Values.logs_ttl_days }} DAY;

-- Materialized View for raw_logs_mv
CREATE MATERIALIZED VIEW IF NOT EXISTS {{ .Values.database }}.raw_logs_mv ON CLUSTER '{{ .Values.clickhouse.clustername }}'
TO {{ .Values.database }}.raw_logs_replicated
AS SELECT * FROM {{ .Values.database }}.kafka_raw_logs_topic;

CREATE TABLE IF NOT EXISTS {{ .Values.database }}.raw_logs_dist ON CLUSTER '{{ .Values.clickhouse.clustername }}'
AS {{ .Values.database }}.raw_logs_replicated
ENGINE = Distributed('{{ .Values.clickhouse.clustername }}', {{ .Values.database }}, raw_logs_replicated, rand());


--------------------------------- SHADOW RAW LOGS TABLES ---------------------------------
-- Replicated Table for shadow raw logs
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.shadow_raw_logs_replicated ON CLUSTER '{{ .Values.clickhouse.clustername }}'
AS {{ .Values.database }}.raw_logs_replicated 
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/{database}/shadow_raw_logs_replicated_v1', '{replica}')
PARTITION BY (toYYYYMMDD(timestamp), org_id, svc_acct_id)
ORDER BY (org_id, svc_acct_id, timestamp)
TTL toDateTime(timestamp) + INTERVAL {{ .Values.logs_ttl_days }} DAY;

-- Distributed Table for shadow_raw_logs
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.shadow_raw_logs_dist ON CLUSTER '{{ .Values.clickhouse.clustername }}'
AS {{ .Values.database }}.shadow_raw_logs_replicated
ENGINE = Distributed('{{ .Values.clickhouse.clustername }}', {{ .Values.database }}, shadow_raw_logs_replicated, rand());




--------------------------------- SELECTOR TRAINING TABLES ---------------------------------
-- Model Selector Training Performance Table
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.model_selector_training_perf_replicated ON CLUSTER '{{ .Values.clickhouse.clustername }}'
(
    `model_selector_id` Int32,
    `org_id` Int32,
    `service_account_id` String,
    `lambda` Float64,
    `accuracy_improvement` Float64,
    `cost_savings` Float64,
    `router_accuracy` Float64,
    `router_cost` Float64,
    `model_distribution` String,           /* JSON string */
    `best_model_accuracy` Float64,
    `best_model_cost` Float64,
    `best_model` String,
    `created_at` DateTime64
)
-- Can't use ReplicatedReplacingMergeTree here as lamda values have to be deleted and inserted again for each training run.
-- Ideally selector_id should be cloned and not be updating the existing records.
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/{database}/model_selector_training_perf_v1', '{replica}')
PARTITION BY (toYYYYMMDD(created_at), org_id, service_account_id, model_selector_id)
ORDER BY (org_id, service_account_id, model_selector_id)
TTL toDateTime(created_at) + INTERVAL {{ .Values.metrics_ttl_days }} DAY;

CREATE TABLE IF NOT EXISTS {{ .Values.database }}.model_selector_training_perf_dist ON CLUSTER '{{ .Values.clickhouse.clustername }}'
AS {{ .Values.database }}.model_selector_training_perf_replicated
ENGINE = Distributed('{{ .Values.clickhouse.clustername }}', {{ .Values.database }}, model_selector_training_perf_replicated, rand());


--------------------------------- EVALUATION JOB LAST RUN TABLES ---------------------------------
-- Replicated Table for eval job last run
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.eval_job_last_run_replicated  ON CLUSTER '{{ .Values.clickhouse.clustername }}' 
(
            job_name String,
            end_time DateTime,
            updated_at DateTime
)
ENGINE = ReplicatedReplacingMergeTree('/clickhouse/tables/{shard}/{database}/eval_job_last_run_v1', '{replica}', updated_at)
PARTITION BY job_name
ORDER BY (job_name);

-- Distributed Table for eval job last run
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.eval_job_last_run_dist ON CLUSTER '{{ .Values.clickhouse.clustername }}'
AS {{ .Values.database }}.eval_job_last_run_replicated
ENGINE = Distributed('{{ .Values.clickhouse.clustername }}', {{ .Values.database }}, eval_job_last_run_replicated, rand());


--------------------------------- EVALUATION METRICS TABLES ---------------------------------

--------------------------------- COST METRICS TABLES ---------------------------------
-- Replicated Table for cost metrics
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.cost_metrics_replicated ON CLUSTER '{{ .Values.clickhouse.clustername }}'
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
PARTITION BY (toYYYYMMDD(timestamp), org_id, svc_acct_id)
ORDER BY (org_id, svc_acct_id, id)
TTL toDateTime(timestamp) + INTERVAL {{ .Values.metrics_ttl_days }} DAY;

CREATE TABLE IF NOT EXISTS {{ .Values.database }}.cost_metrics_dist ON CLUSTER '{{ .Values.clickhouse.clustername }}'
AS {{ .Values.database }}.cost_metrics_replicated
ENGINE = Distributed('{{ .Values.clickhouse.clustername }}', {{ .Values.database }}, cost_metrics_replicated, rand());

--------------------------------- QUALITY SCORES TABLES ---------------------------------
-- Replicated Table for quality scores
CREATE TABLE IF NOT EXISTS {{ .Values.database }}.quality_scores_replicated ON CLUSTER '{{ .Values.clickhouse.clustername }}'
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
PARTITION BY (toYYYYMMDD(timestamp), org_id, svc_acct_id)
ORDER BY (org_id, svc_acct_id, eval_id, id)
TTL toDateTime(timestamp) + INTERVAL {{ .Values.metrics_ttl_days }} DAY;

CREATE TABLE IF NOT EXISTS {{ .Values.database }}.quality_scores_dist ON CLUSTER '{{ .Values.clickhouse.clustername }}'
AS {{ .Values.database }}.quality_scores_replicated
ENGINE = Distributed('{{ .Values.clickhouse.clustername }}', {{ .Values.database }}, quality_scores_replicated, rand());

