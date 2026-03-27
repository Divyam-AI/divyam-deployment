#############################################
# Kubernetes Provider (uses AKS from main.tf)
#############################################

provider "kubernetes" {
  host                   = local.aks_cluster.kube_config[0].host
  client_certificate     = base64decode(local.aks_cluster.kube_config[0].client_certificate)
  client_key             = base64decode(local.aks_cluster.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(local.aks_cluster.kube_config[0].cluster_ca_certificate)
}

#############################################
# AKS NodeClasses
#############################################

# CPU On-Demand
resource "kubernetes_manifest" "nodeclass_cpu_ondemand" {
  manifest = {
    apiVersion = "karpenter.azure.com/v1beta1"
    kind       = "AKSNodeClass"
    metadata = {
      name = "cpu-ondemand"
    }
    spec = {
      skuFamily    = "GeneralPurpose"
      osDiskSizeGB = 128
    }
  }
}

# CPU Spot
resource "kubernetes_manifest" "nodeclass_cpu_spot" {
  manifest = {
    apiVersion = "karpenter.azure.com/v1beta1"
    kind       = "AKSNodeClass"
    metadata = {
      name = "cpu-spot"
    }
    spec = {
      skuFamily = "GeneralPurpose"
      osDiskSizeGB = 128
      spot = {
        enabled = true
      }
    }
  }
}

# GPU On-Demand
resource "kubernetes_manifest" "nodeclass_gpu_ondemand" {
  manifest = {
    apiVersion = "karpenter.azure.com/v1beta1"
    kind       = "AKSNodeClass"
    metadata = {
      name = "gpu-ondemand"
    }
    spec = {
      skuFamily    = "GPU"
      osDiskSizeGB = 256
    }
  }
}

# GPU Spot
resource "kubernetes_manifest" "nodeclass_gpu_spot" {
  manifest = {
    apiVersion = "karpenter.azure.com/v1beta1"
    kind       = "AKSNodeClass"
    metadata = {
      name = "gpu-spot"
    }
    spec = {
      skuFamily    = "GPU"
      osDiskSizeGB = 256
      spot = {
        enabled = true
      }
    }
  }
}

#############################################
# NodePools
#############################################

# CPU On-Demand Pool
resource "kubernetes_manifest" "nodepool_cpu_ondemand" {
  depends_on = [kubernetes_manifest.nodeclass_cpu_ondemand]

  manifest = {
    apiVersion = "karpenter.sh/v1beta1"
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
            name = "cpu-ondemand"
          }
          requirements = [
            {
              key      = "kubernetes.io/os"
              operator = "In"
              values   = ["linux"]
            }
          ]
        }
      }
    }
  }
}

# CPU Spot Pool
resource "kubernetes_manifest" "nodepool_cpu_spot" {
  depends_on = [kubernetes_manifest.nodeclass_cpu_spot]

  manifest = {
    apiVersion = "karpenter.sh/v1beta1"
    kind       = "NodePool"
    metadata = {
      name = "cpu-spot"
    }
    spec = {
      template = {
        metadata = {
          labels = {
            "karpenter.sh/capacity-type" = "spot"
            workload-type                = "cpu"
          }
        }
        spec = {
          nodeClassRef = {
            name = "cpu-spot"
          }
          requirements = [
            {
              key      = "kubernetes.io/os"
              operator = "In"
              values   = ["linux"]
            }
          ]
        }
      }
    }
  }
}

# GPU On-Demand Pool
resource "kubernetes_manifest" "nodepool_gpu_ondemand" {
  depends_on = [kubernetes_manifest.nodeclass_gpu_ondemand]

  manifest = {
    apiVersion = "karpenter.sh/v1beta1"
    kind       = "NodePool"
    metadata = {
      name = "gpu-ondemand"
    }
    spec = {
      template = {
        metadata = {
          labels = {
            accelerator = "gpu"
          }
        }
        spec = {
          nodeClassRef = {
            name = "gpu-ondemand"
          }
          requirements = [
            {
              key      = "kubernetes.io/os"
              operator = "In"
              values   = ["linux"]
            }
          ]
        }
      }
    }
  }
}

# GPU Spot Pool
resource "kubernetes_manifest" "nodepool_gpu_spot" {
  depends_on = [kubernetes_manifest.nodeclass_gpu_spot]

  manifest = {
    apiVersion = "karpenter.sh/v1beta1"
    kind       = "NodePool"
    metadata = {
      name = "gpu-spot"
    }
    spec = {
      template = {
        metadata = {
          labels = {
            accelerator                    = "gpu"
            "karpenter.sh/capacity-type" = "spot"
          }
        }
        spec = {
          nodeClassRef = {
            name = "gpu-spot"
          }
          requirements = [
            {
              key      = "kubernetes.io/os"
              operator = "In"
              values   = ["linux"]
            }
          ]
        }
      }
    }
  }
}

#############################################
# Helm Provider
#############################################
provider "helm" {
  kubernetes = {
    host                   = local.aks_cluster.kube_config[0].host
    client_certificate     = base64decode(local.aks_cluster.kube_config[0].client_certificate)
    client_key             = base64decode(local.aks_cluster.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(local.aks_cluster.kube_config[0].cluster_ca_certificate)
  }
}

resource "helm_release" "nvidia_device_plugin" {
  name       = "nvidia-device-plugin"
  repository = "https://nvidia.github.io/k8s-device-plugin"
  chart      = "nvidia-device-plugin"
  namespace  = "kube-system"

  create_namespace = false

  # Ensure cluster exists first
  depends_on = [
    azurerm_kubernetes_cluster.aks_cluster
  ]

  # Optional but useful for stability
  timeout = 600
}