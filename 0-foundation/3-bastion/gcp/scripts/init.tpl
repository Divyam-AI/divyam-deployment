#!/bin/bash
set -e

echo "Installing kubectl..."

# Wait for apt locks (cloud-init may still be running).
WAIT_TIME=5
MAX_RETRIES=300
retry=0
while fuser /var/lib/dpkg/lock >/dev/null 2>&1 || \
      fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || \
      fuser /var/cache/apt/archives/lock >/dev/null 2>&1
do
  if [ "$retry" -ge "$MAX_RETRIES" ]; then
    echo "ERROR: apt lock held too long. Exiting."
    exit 1
  fi
  echo "Waiting for apt lock... ($((retry+1))/$MAX_RETRIES)"
  sleep $WAIT_TIME
  retry=$((retry + 1))
done

apt-get update -y || true
apt-get install -y apt-transport-https ca-certificates curl gpg

# Install kubectl (Kubernetes official repo)
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list
apt-get update -y || true
apt-get install -y kubectl
kubectl version --client
echo "kubectl installed."

%{ if configure_kubectl && cluster_name != "" && cluster_region != "" && cluster_project_id != "" ~}
# Install cloud SDK (for get-credentials) and write setup script (run once cluster exists).
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
apt-get update -y || true
apt-get install -y google-cloud-sdk-gke-gcloud-auth-plugin google-cloud-cli

# Write script so it can be invoked on the bastion after the cluster is created (1-platform).
mkdir -p /root/.kube
cat > /usr/local/bin/setup-kubectl << 'INNER_EOF'
#!/bin/bash
set -e
CLUSTER_NAME="CLUSTER_NAME_PLACEHOLDER"
CLUSTER_REGION="CLUSTER_REGION_PLACEHOLDER"
CLUSTER_PROJECT="CLUSTER_PROJECT_PLACEHOLDER"
if [ -z "$CLUSTER_NAME" ] || [ -z "$CLUSTER_REGION" ] || [ -z "$CLUSTER_PROJECT" ]; then
  echo "Cluster name, region or project not set." >&2
  exit 1
fi
export CLOUDSDK_CORE_PROJECT="$CLUSTER_PROJECT"
if gcloud container clusters get-credentials "$CLUSTER_NAME" --region "$CLUSTER_REGION" --project "$CLUSTER_PROJECT"; then
  echo "kubectl configured for cluster $CLUSTER_NAME."
else
  echo "Failed to get credentials. Ensure the cluster exists and this instance has access." >&2
  exit 1
fi
INNER_EOF
sed -i "s#CLUSTER_NAME_PLACEHOLDER#${cluster_name}#g; s#CLUSTER_REGION_PLACEHOLDER#${cluster_region}#g; s#CLUSTER_PROJECT_PLACEHOLDER#${cluster_project_id}#g" /usr/local/bin/setup-kubectl
chmod +x /usr/local/bin/setup-kubectl

# Try once at boot (cluster may not exist yet).
if setup-kubectl 2>/dev/null; then
  echo "Cluster credentials fetched at boot."
else
  echo "Cluster may not exist yet. Once the cluster is created (1-platform), run on this host: setup-kubectl"
fi
%{ else ~}
echo "Kubectl setup not requested (set configure_kubectl = true in bastion section and ensure k8s section has name)."
echo "To configure later, run on this host the appropriate get-credentials command for your cloud."
%{ endif ~}
