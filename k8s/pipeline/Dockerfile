# Pinned Ubuntu LTS (not :latest). Bump intentionally when adopting a newer OS baseline.
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG HELMFILE_VERSION=v1.4.4
ARG HELM_DIFF_VERSION=v3.7.0
ARG YQ_VERSION=v4.44.3

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    jq \
    unzip \
    python3 \
    python3-pip \
    software-properties-common \
  && rm -rf /var/lib/apt/lists/*

# Install Helm from official repository.
RUN curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey \
    | gpg --dearmor \
    | tee /usr/share/keyrings/helm.gpg >/dev/null \
  && echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" \
    | tee /etc/apt/sources.list.d/helm-stable-debian.list >/dev/null \
  && apt-get update \
  && apt-get install -y --no-install-recommends helm \
  && rm -rf /var/lib/apt/lists/*

# Install kubectl using Kubernetes apt repository.
RUN mkdir -p -m 755 /etc/apt/keyrings \
  && curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
    | gpg --dearmor \
    | tee /etc/apt/keyrings/kubernetes-apt-keyring.gpg >/dev/null \
  && echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" \
    | tee /etc/apt/sources.list.d/kubernetes.list >/dev/null \
  && apt-get update \
  && apt-get install -y --no-install-recommends kubectl \
  && rm -rf /var/lib/apt/lists/*

# Install Helmfile binary.
RUN curl -L -o /tmp/helmfile.tar.gz \
    "https://github.com/helmfile/helmfile/releases/download/${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION#v}_linux_amd64.tar.gz" \
  && tar -xzf /tmp/helmfile.tar.gz -C /tmp \
  && mv /tmp/helmfile /usr/local/bin/helmfile \
  && chmod +x /usr/local/bin/helmfile \
  && rm -f /tmp/helmfile.tar.gz

# Install yq binary for YAML processing.
RUN curl -L -o /usr/local/bin/yq \
    "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
  && chmod +x /usr/local/bin/yq

# Install Helm diff plugin version used by CI validation.
RUN helm plugin install https://github.com/databus23/helm-diff --version "${HELM_DIFF_VERSION}"

# Install Azure CLI.
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Install Google Cloud CLI.
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" \
    | tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null \
  && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    | gpg --dearmor \
    | tee /usr/share/keyrings/cloud.google.gpg >/dev/null \
  && apt-get update \
  && apt-get install -y --no-install-recommends google-cloud-cli google-cloud-cli-gke-gcloud-auth-plugin \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

CMD ["/bin/bash"]
