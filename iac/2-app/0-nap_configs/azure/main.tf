#############################################
# Kubernetes & Helm Providers (from AKS dependency)
#############################################

provider "kubernetes" {
  host                   = var.kube_config.host
  client_certificate     = base64decode(var.kube_config.client_certificate)
  client_key             = base64decode(var.kube_config.client_key)
  cluster_ca_certificate = base64decode(var.kube_config.cluster_ca_certificate)
}

provider "helm" {
  kubernetes = {
    host                   = var.kube_config.host
    client_certificate     = base64decode(var.kube_config.client_certificate)
    client_key             = base64decode(var.kube_config.client_key)
    cluster_ca_certificate = base64decode(var.kube_config.cluster_ca_certificate)
  }
}

locals {
  nap_tag_context = merge(var.nap_tag_globals, var.nap_tag_context)
  nap_rendered_tags = {
    for k, v in var.nap_common_tags :
    k => replace(
      v,
      "/#\\{([^}]+)\\}/",
      lookup(local.nap_tag_context, try(regex("#\\{([^}]+)\\}", v)[0], ""), "")
    )
  }

  # Convert rendered common tags into Kubernetes label-safe key/value pairs for NodePool template labels.
  # Keep this separate from Azure tags because Azure resource tags can preserve the original rendered values.
  sanitized_custom_labels = {
    for k, v in local.nap_rendered_tags :
    regexreplace(regexreplace(substr(regexreplace(lower(k), "[^a-z0-9_.-]", "-"), 0, 63), "^[^a-z0-9]+", ""), "[^a-z0-9]+$", "") =>
    coalesce(
      try(regexreplace(regexreplace(substr(regexreplace(lower(v), "[^a-z0-9_.-]", "-"), 0, 63), "^[^a-z0-9]+", ""), "[^a-z0-9]+$", ""), null),
      "na"
    )
    if length(regexreplace(regexreplace(substr(regexreplace(lower(k), "[^a-z0-9_.-]", "-"), 0, 63), "^[^a-z0-9]+", ""), "[^a-z0-9]+$", "")) > 0
  }
}

#############################################
# NodePools
#############################################

# Dedicated AKSNodeClass used only to pass rendered common tags to Azure resources created for NAP nodes.
# Intentionally tag-only: do not set subnet/image/disk or any behavioral fields here.
resource "kubernetes_manifest" "aks_nodeclass_custom_tags" {
  manifest = {
    apiVersion = "karpenter.azure.com/v1beta1"
    kind       = "AKSNodeClass"
    metadata = {
      name = "divyam-custom-nodeclass"
    }
    spec = {
      tags = local.nap_rendered_tags
    }
  }
}

# CPU On-Demand Pool
resource "kubernetes_manifest" "nodepool_cpu_ondemand" {

  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "cpu-ondemand"
    }
    spec = {
      template = {
        metadata = {
          labels = merge({
            workload-type = "cpu"
          }, local.sanitized_custom_labels)
        }
        spec = {
          nodeClassRef = {
            name  = kubernetes_manifest.aks_nodeclass_custom_tags.manifest.metadata.name
            kind  = "AKSNodeClass"
            group = "karpenter.azure.com"
          }
          requirements = [
            {
              key      = "kubernetes.io/os"
              operator = "In"
              values   = ["linux"]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["on-demand"]
            },
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64"]
            }
          ]
        }
      }
    }
  }
}

# CPU Spot Pool
resource "kubernetes_manifest" "nodepool_cpu_spot" {

  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "cpu-spot"
    }
    spec = {
      template = {
        metadata = {
          labels = merge({
            workload-type = "cpu"
          }, local.sanitized_custom_labels)
        }
        spec = {
          nodeClassRef = {
            name  = kubernetes_manifest.aks_nodeclass_custom_tags.manifest.metadata.name
            kind  = "AKSNodeClass"
            group = "karpenter.azure.com"
          }
          requirements = [
            {
              key      = "kubernetes.io/os"
              operator = "In"
              values   = ["linux"]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["spot"]
            },
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64"]
            }
          ]
        }
      }
    }
  }
}

# GPU On-Demand Pool
resource "kubernetes_manifest" "nodepool_gpu_ondemand" {

  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "gpu-ondemand"
    }
    spec = {
      template = {
        metadata = {
          labels = merge({
            "nvidia.com/gpu.present" = "true"
          }, local.sanitized_custom_labels)
        }
        spec = {
          taints = [
            {
              key    = "nvidia.com/gpu"
              effect = "NoSchedule"
            }
          ]
          nodeClassRef = {
            name  = kubernetes_manifest.aks_nodeclass_custom_tags.manifest.metadata.name
            kind  = "AKSNodeClass"
            group = "karpenter.azure.com"
          }
          requirements = [
            {
              key      = "kubernetes.io/os"
              operator = "In"
              values   = ["linux"]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["on-demand"]
            },
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64"]
            }
          ]
        }
      }
    }
  }
}

# GPU Spot Pool
resource "kubernetes_manifest" "nodepool_gpu_spot" {

  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "gpu-spot"
    }
    spec = {
      template = {
        metadata = {
          labels = merge({
            "nvidia.com/gpu.present" = "true"
          }, local.sanitized_custom_labels)
        }
        spec = {
          taints = [
            {
              key    = "nvidia.com/gpu"
              effect = "NoSchedule"
            }
          ]
          nodeClassRef = {
            name  = kubernetes_manifest.aks_nodeclass_custom_tags.manifest.metadata.name
            kind  = "AKSNodeClass"
            group = "karpenter.azure.com"
          }
          requirements = [
            {
              key      = "kubernetes.io/os"
              operator = "In"
              values   = ["linux"]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["spot"]
            },
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64"]
            }
          ]
        }
      }
    }
  }
}

#############################################
# NVIDIA GPU Device Plugin
#############################################
resource "helm_release" "nvidia_device_plugin" {
  name       = "nvidia-device-plugin"
  repository = "https://nvidia.github.io/k8s-device-plugin"
  chart      = "nvidia-device-plugin"
  namespace  = "kube-system"

  create_namespace = false

  timeout = 600
}
