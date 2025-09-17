#!/usr/bin/env bash
set -euo pipefail

eval "$(jq -r '@sh "GCP_SA_KEY_JSON=\(.GCP_SA_KEY_JSON)"')"

# Check if the key is present
if [[ -z "${GCP_SA_KEY_JSON:-}" ]]; then
  echo "Missing GCP_SA_KEY_JSON environment variable"
  exit 1
fi

# Extract fields from the key JSON
CLIENT_EMAIL=$(echo "$GCP_SA_KEY_JSON" | jq -r .client_email)
PRIVATE_KEY=$(echo "$GCP_SA_KEY_JSON" | jq -r .private_key | sed 's/\\n/\n/g')

# Set issued-at and expiration
IAT=$(date +%s)
EXP=$((IAT + 3600))

# Encode JWT header
HEADER_BASE64=$(printf '{"alg":"RS256","typ":"JWT"}' | openssl base64 -A | tr '+/' '-_' | tr -d '=')

# Create payload
PAYLOAD=$(cat <<EOF
{
  "iss": "$CLIENT_EMAIL",
  "scope": "https://www.googleapis.com/auth/cloud-platform",
  "aud": "https://oauth2.googleapis.com/token",
  "iat": $IAT,
  "exp": $EXP
}
EOF
)
PAYLOAD_BASE64=$(printf '%s' "$PAYLOAD" | openssl base64 -A | tr '+/' '-_' | tr -d '=')

# Create the signature
DATA="${HEADER_BASE64}.${PAYLOAD_BASE64}"
SIGNATURE=$(printf '%s' "$DATA" | openssl dgst -sha256 -sign <(echo "$PRIVATE_KEY") | openssl base64 -A | tr '+/' '-_' | tr -d '=')
JWT="${DATA}.${SIGNATURE}"

# Request access token
ACCESS_TOKEN=$(curl -s -X POST https://oauth2.googleapis.com/token \
  -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer" \
  -d "assertion=$JWT" \
  | jq -r .access_token)

echo "{\"token\": \"$ACCESS_TOKEN\"}"
