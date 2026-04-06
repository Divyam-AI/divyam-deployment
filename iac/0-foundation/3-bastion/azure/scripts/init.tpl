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

%{ if configure_kubectl && cluster_name != "" && resource_group_name != "" ~}
# Install Azure CLI and write setup script to fetch cluster credentials (run once cluster exists).
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Write script so it can be invoked on the bastion after the cluster is created (1-platform).
mkdir -p /home/${admin_username}/.kube
cat > /usr/local/bin/setup-kubectl << 'INNER_EOF'
#!/bin/bash
set -e
CLUSTER_NAME="CLUSTER_NAME_PLACEHOLDER"
RESOURCE_GROUP="RESOURCE_GROUP_PLACEHOLDER"
ADMIN_USER="ADMIN_USER_PLACEHOLDER"
KUBECONFIG_PATH="/home/ADMIN_USER_PLACEHOLDER/.kube/config"
if [ -z "$CLUSTER_NAME" ] || [ -z "$RESOURCE_GROUP" ]; then
  echo "Cluster name or resource group not set." >&2
  exit 1
fi
if ! az login --identity --output none 2>/dev/null; then
  echo "az login --identity failed. Ensure the VM has a system-assigned managed identity." >&2
  exit 1
fi
if az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --file "$KUBECONFIG_PATH" --overwrite-existing; then
  chown -R $ADMIN_USER:$ADMIN_USER "$(dirname "$KUBECONFIG_PATH")"
  chmod 600 "$KUBECONFIG_PATH"
  echo "kubectl configured for cluster $CLUSTER_NAME."
else
  echo "Failed to get credentials. Ensure the cluster exists and the VM identity has the required role on the cluster." >&2
  exit 1
fi
INNER_EOF
sed -i "s#CLUSTER_NAME_PLACEHOLDER#${cluster_name}#g; s#RESOURCE_GROUP_PLACEHOLDER#${resource_group_name}#g; s#ADMIN_USER_PLACEHOLDER#${admin_username}#g" /usr/local/bin/setup-kubectl
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
