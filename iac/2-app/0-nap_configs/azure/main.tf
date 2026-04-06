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

#############################################
# NodePools
#############################################

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
            workload-type = "cpu"
          }
        }
        spec = {
          nodeClassRef = {
            name  = "default"
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
          labels = {
            workload-type = "cpu"
          }
        }
        spec = {
          nodeClassRef = {
            name  = "default"
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
          labels = {
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
            name  = "default"
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
          labels = {
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
            name  = "default"
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
