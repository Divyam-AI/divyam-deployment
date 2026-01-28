import os

DRY_RUN=True
ENV="preprod"

METRICS_TTL_DAYS="365"
LOGS_TTL_DAYS="180"
K8s_CLICKHOUSE_NAMESPACE=f"clickhouse-{ENV}-ns"
CLICKHOUSE_CLUSTER_NAME="clickhouse-prep" #f"clk-{ENV}" # TODO: Change this to the actual cluster name
CLUSTER_LABEL=f"clickhouse.altinity.com/chi=clk-{ENV}"
CLICKHOUSE_HOST="localhost" #f"{CLICKHOUSE_CLUSTER_NAME}-svc.{K8s_CLICKHOUSE_NAMESPACE}.svc.cluster.local"
CLICKHOUSE_PORT=8123
CLICKHOUSE_USERNAME="default"
CLICKHOUSE_DATABASE=f"sudhir_test_db_{ENV}" #TODO: Change this to the actual database name
KAFKA_BROKER_LIST=f"kafka-{ENV}-cluster-kafka-bootstrap.kafka-{ENV}-ns.svc.cluster.local:9092"
MYSQL_DATABASE=f"divyam_{ENV}"
MYSQL_HOST=f"mysql-{ENV}-svc.mysql-{ENV}-ns.svc.cluster.local"
MYSQL_USERNAME=f"divyam-{ENV}"
MYSQL_PASSWORD_ENV_VAR=f"TF_VAR_divyam_{ENV}_mysql_db_password"
CLICKHOUSE_PASSWORD_ENV_VAR=f"TF_VAR_divyam_{ENV}_clickhouse_db_password"

# Check if CLICKHOUSE_PASSWORD_ENV_VAR is set in the environment variables and if not, fail
CLICKHOUSE_PASSWORD=os.getenv(CLICKHOUSE_PASSWORD_ENV_VAR, None)
if CLICKHOUSE_PASSWORD is None:
    print(f"❌ ERROR: CLICKHOUSE PASSWORD is not set in the environment variable {CLICKHOUSE_PASSWORD_ENV_VAR} Please set the environment variable and try again.")
    exit(1)

# Check if MYSQL_PASSWORD_ENV_VAR is set in the environment variables and if not, fail
MYSQL_PASSWORD=os.getenv(MYSQL_PASSWORD_ENV_VAR, None)
if MYSQL_PASSWORD is None:
    print(f"❌ ERROR: MYSQL PASSWORD is not set in the environment variable {MYSQL_PASSWORD_ENV_VAR} Please set the environment variable and try again.")
    exit(1)