#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="qdrant-preprod-ns"
LABEL_SELECTOR="app=qdrant"
LOCAL_BASE_PORT=7000
QDRANT_PORT=6333

COLLECTION_NAME="test_collection_$(date +%s)"
ALIAS_NAME="test_alias_$(date +%s)"

echo "🔍 Fetching Qdrant pods..."
PODS=($(kubectl get pods -n $NAMESPACE -l $LABEL_SELECTOR -o jsonpath='{.items[*].metadata.name}'))

if [ ${#PODS[@]} -eq 0 ]; then
  echo "❌ No pods found"
  exit 1
fi

echo "Found pods: ${PODS[*]}"

# Track port-forwards
PORTS=()
PIDS=()

echo "🚀 Starting port-forwards..."
for i in "${!PODS[@]}"; do
  POD=${PODS[$i]}
  LOCAL_PORT=$((LOCAL_BASE_PORT + i))

  kubectl port-forward -n $NAMESPACE pod/$POD ${LOCAL_PORT}:${QDRANT_PORT} >/dev/null 2>&1 &
  PID=$!

  PORTS+=($LOCAL_PORT)
  PIDS+=($PID)

  echo "Pod $POD → localhost:$LOCAL_PORT"
done

# Cleanup on exit
cleanup() {
  echo "🧹 Cleaning up port-forwards..."
  for pid in "${PIDS[@]}"; do
    kill $pid >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

sleep 5  # wait for port-forward to stabilize

PRIMARY_PORT=${PORTS[0]}

echo "📦 Creating collection on primary (port $PRIMARY_PORT)..."

curl -s -X PUT "http://localhost:${PRIMARY_PORT}/collections/${COLLECTION_NAME}" \
  -H "Content-Type: application/json" \
  -d '{
    "vectors": {
      "size": 4,
      "distance": "Cosine"
    }
  }' | jq

echo "🔗 Creating alias on primary..."

curl -s -X POST "http://localhost:${PRIMARY_PORT}/collections/aliases" \
  -H "Content-Type: application/json" \
  -d "{
    \"actions\": [
      {
        \"create_alias\": {
          \"collection_name\": \"${COLLECTION_NAME}\",
          \"alias_name\": \"${ALIAS_NAME}\"
        }
      }
    ]
  }" | jq

echo ""
echo "⏳ Waiting for propagation..."
sleep 5

echo ""
echo "🔎 Checking collection + alias on all replicas..."

for i in "${!PORTS[@]}"; do
  PORT=${PORTS[$i]}
  POD=${PODS[$i]}

  echo ""
  echo "➡️ Checking pod $POD (port $PORT)"

  echo "Collections:"
  curl -s "http://localhost:${PORT}/collections" | jq '.result.collections[].name'

  echo "Alias lookup:"
  curl -s "http://localhost:${PORT}/aliases/" 
#   | jq '.result.name' || echo "Alias not found"
done

echo ""
echo "✅ Done"