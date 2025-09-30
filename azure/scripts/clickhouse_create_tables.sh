#!/bin/bash
# This script creates tables in a ClickHouse cluster.
# e.g. ./create_clickhouse_tables.sh clickhouse-dev-ns clickhouse-dev
#set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <namespace> <clustername> [queries_file]"
  exit 1
fi

NAMESPACE="$1"
CLUSTER_NAME="$2"
QUERIES_FILE="${3:-clickhouse_create_tables.sql}"
MYSQL_SOURCE_DB="divyam_dev"
MYSQL_HOST="mysql-dev-svc.mysql-dev-ns.svc.cluster.local"
MYSQL_USERNAME="divyam-dev"
MYSQL_PASSWORD="$TF_VAR_divyam_db_password"

# If MYSQL_PASSWORD is not set, ask to export $TF_VAR_divyam_db_password
if [[ -z "$MYSQL_PASSWORD" ]]; then
  echo "❌ ERROR: MYSQL_PASSWORD is not set"
  echo "Please export $TF_VAR_divyam_db_password with the password"
  exit 1
fi

# Ask for confirmation to proceed for the cluster
read -p "Are you sure you want to proceed with the cluster $CLUSTER_NAME ? (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
  echo "❌ ERROR: User did not confirm to proceed"
  exit 1
fi

CLUSTER_LABEL="clickhouse.altinity.com/chi=clk-dev"
DATABASE="divyam_router_logs"
KAFKA_BROKER_LIST="kafka-dev-cluster-kafka-bootstrap.kafka-dev-ns.svc.cluster.local:9092"

# Collect ClickHouse pod names
PODS=$(kubectl get pods -n "$NAMESPACE" -l "$CLUSTER_LABEL" -o jsonpath='{.items[*].metadata.name}')
FIRST_POD=$(echo "$PODS" | awk '{print $1}')

echo "PODS: $PODS"
echo "FIRST_POD: $FIRST_POD"

run_query_all_pods() {
  local query="$1"
  echo "-------------------------------------------------------------------"
  echo "Running query on ALL pods:"
  echo "$query"
  echo "-------------------------------------------------------------------"

  for POD in $PODS; do
    echo ">>> Executing on pod: $POD"
    if ! kubectl exec -n "$NAMESPACE" -i "$POD" -- \
      clickhouse-client --multiquery --query "$query"; then
      echo "❌ ERROR: Query failed on pod $POD"
      exit 1
    fi
  done
  return 0
}

run_query_any_pod() {
  local query="$1"
  echo "-------------------------------------------------------------------"
  echo "Running query on ANY pod ($FIRST_POD):"
  echo "$query"
  echo "-------------------------------------------------------------------"

  if ! kubectl exec -n "$NAMESPACE" -i "$FIRST_POD" -- \
    clickhouse-client --multiquery --query "$query"; then
    echo "❌ ERROR: Query failed on pod $FIRST_POD"
    exit 1
  fi
  return 0
}

verify_table() {
  local db="$1"
  local tbl="$2"
  echo "🔎 Verifying $db.$tbl exists on all pods..."
  for POD in $PODS; do
    echo ">>> Checking on pod: $POD"
    if ! kubectl exec -n "$NAMESPACE" -i "$POD" -- \
      clickhouse-client --query "EXISTS TABLE $db.$tbl FORMAT TabSeparated" | grep -q "1"; then
      echo "❌ ERROR: Table $db.$tbl not found on $POD"
      exit 1
    fi
  done
  echo "✅ Verified: $db.$tbl exists on all pods"
}

# Drop + create database fresh before running queries
echo "⚠️ Dropping and recreating database: $DATABASE"
run_query_any_pod "DROP DATABASE IF EXISTS $DATABASE ON CLUSTER '$CLUSTER_NAME';"
run_query_any_pod "CREATE DATABASE $DATABASE ON CLUSTER '$CLUSTER_NAME';"

# Loop through queries in the .sql file
current_query=""
lines=()
while IFS= read -r line || [[ -n "$line" ]]; do
  lines+=("$line")
done < "$QUERIES_FILE"

for line in "${lines[@]}"; do
  # Trim spaces
  trimmed="$(echo "$line" | xargs)"

  # Skip empty lines and comments
  if [[ -z "$trimmed" || "$trimmed" =~ ^-- ]]; then
    continue
  fi

  # Accumulate query lines
  current_query+="$line"$'\n'

  # Check if this line ends with ";"
  if [[ "$line" =~ \;[[:space:]]*$ ]]; then
    query_prepared="${current_query//\{\{ .Values.database \}\}/$DATABASE}"
    query_prepared="${query_prepared//\{\{ include \"clickhouse.clustername\" . \}\}/$CLUSTER_NAME}"
    query_prepared="${query_prepared//\{\{ .Values.kafka_integration.broker_list \}\}/$KAFKA_BROKER_LIST}"
    query_prepared="${query_prepared//\{\{ .Values.mysql_integration.host \}\}/$MYSQL_HOST}"
    query_prepared="${query_prepared//\{\{ .Values.mysql_integration.source_database \}\}/$MYSQL_SOURCE_DB}"
    query_prepared="${query_prepared//\{\{ .Values.mysql_integration.username \}\}/$MYSQL_USERNAME}"
    query_prepared="${query_prepared//\{\{ .Values.mysql_integration.password \}\}/$MYSQL_PASSWORD}"

    run_query_any_pod "$query_prepared"

    # Extract table name for verification (best-effort regex)
    if [[ "$query_prepared" =~ CREATE[[:space:]]+TABLE[[:space:]]+IF[[:space:]]+NOT[[:space:]]+EXISTS[[:space:]]+([^.]+)\.([a-zA-Z0-9_]+) ]]; then
      db="${BASH_REMATCH[1]}"
      tbl="${BASH_REMATCH[2]}"
      verify_table "$db" "$tbl"
    fi

    current_query=""  # reset buffer
  fi
done < "$QUERIES_FILE"

echo "🎉 All queries executed and verified successfully."