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

  # Kubernetes label key/value rules (subset): alphanumeric + ._- , <=63 chars, must start/end with alphanumeric.
  # OpenTofu builds in this repo may not expose regexreplace(); use regexall + regex instead.
  _k8s_label_allowed_chars = "[a-z0-9_.-]"
  # Use (?:...) so regex() returns a single string (capturing groups would return a tuple).
  _k8s_label_body = "[a-z0-9](?:[a-z0-9_.-]{0,61}[a-z0-9])?|[a-z0-9]"

  # Strip to allowed runes, then take the first valid DNS-like label segment (max 63 chars; non-capturing group so regex() is a string).
  _k8s_label_key = {
    for k, _ in local.nap_rendered_tags :
    k => try(
      regex(
        local._k8s_label_body,
        join("", regexall(local._k8s_label_allowed_chars, lower(k)))
      ),
      ""
    )
  }
  _k8s_label_value = {
    for k, v in local.nap_rendered_tags :
    k => try(
      regex(
        local._k8s_label_body,
        join("", regexall(local._k8s_label_allowed_chars, lower(v)))
      ),
      ""
    )
  }

  # Convert rendered common tags into Kubernetes label-safe key/value pairs for NodePool template labels.
  # Keep this separate from Azure tags because Azure resource tags can preserve the original rendered values.
  sanitized_custom_labels = {
    for k, v in local.nap_rendered_tags :
    local._k8s_label_key[k] => coalesce(local._k8s_label_value[k] != "" ? local._k8s_label_value[k] : null, "na")
    if local._k8s_label_key[k] != ""
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
          labels = {
            "divyam.ai/nodepool-name" = "cpu-ondemand"
          }
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
            },
            {
              key      = "node.kubernetes.io/instance-type"
              operator = "In"
              values   = var.cpu_instance_types
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
          labels = {
            "divyam.ai/nodepool-name" = "cpu-spot"
          }
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
            },
            {
              key      = "node.kubernetes.io/instance-type"
              operator = "In"
              values   = var.cpu_instance_types
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
          labels = {
            "divyam.ai/nodepool-name" = "gpu-ondemand",
            "nvidia.com/gpu.present" = "true"
          }
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
            },
            {
              key      = "nvidia.com/gpu.present"
              operator = "In"
              values   = ["true"]
            },
            {
              key      = "karpenter.azure.com/sku-family"
              operator = "In"
              values   = ["N"]
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
          labels = {
            "divyam.ai/nodepool-name" = "gpu-spot",
            "nvidia.com/gpu.present" = "true"
          }
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
            },
            {
              key      = "nvidia.com/gpu.present"
              operator = "In"
              values   = ["true"]
            },
            {
              key      = "karpenter.azure.com/sku-family"
              operator = "In"
              values   = ["N"]
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
