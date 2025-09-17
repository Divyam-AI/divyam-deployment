#!/bin/bash

set -e

echo "Installing kubectl on Debian/Ubuntu..."

# Wait for apt locks to be released. Some background processes run in parallel
# with cloud init and take the lock. Wait for them to finish.
WAIT_TIME=5     # seconds
MAX_RETRIES=300  # retries (~2.5 minutes total wait)

retry=0
while fuser /var/lib/dpkg/lock >/dev/null 2>&1 || \
      fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || \
      fuser /var/cache/apt/archives/lock >/dev/null 2>&1
do
  if [ "$retry" -ge "$MAX_RETRIES" ]; then
    echo "ERROR: apt lock held too long. Exiting."
    exit 1
  fi
  echo "Waiting for apt lock to be released... ($((retry+1))/$MAX_RETRIES)"
  sleep $WAIT_TIME
  retry=$((retry + 1))
done

echo "Apt locks released. Proceeding with update and install."

# Update system packages
sudo apt-get update -y || true

# Install required packages
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# Download Google Cloud public signing key
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # allow unprivileged APT programs to read this keyring

# Add Kubernetes apt repository
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list   # helps tools such as command-not-found to work correctly

# Update package index with new repo
sudo apt-get update -y || true

# Install kubectl
sudo apt-get install -y kubectl

# Verify installation
kubectl version --client

echo "✅ kubectl installed successfully!"

echo "Installing kube-config on for AKS clusters..."

# Create directories
mkdir -p /home/${admin_username}/.kube

# Generate kube-config for each AK cluster
%{ for cluster_name, config in kube_config_map ~}
cat > /home/${admin_username}/.kube/config_${cluster_name} <<EOF
${replace(config, "$", "\\$")}
EOF
chmod 600 /home/${admin_username}/.kube/config_${cluster_name}
chown ${admin_username}:${admin_username} /home/${admin_username}/.kube/config_${cluster_name}
%{ endfor }

# Symlink default config to the first file found
FIRST_CONFIG=$(find /home/${admin_username}/.kube -name "config_*" | sort | head -n 1)
if [ -n "$FIRST_CONFIG" ]; then
  ln -sfn "$FIRST_CONFIG" /home/${admin_username}/.kube/config
fi
