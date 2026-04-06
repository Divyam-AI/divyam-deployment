output "nodepool_names" {
  description = "Names of the Karpenter NodePools created"
  value = [
    kubernetes_manifest.nodepool_cpu_ondemand.manifest.metadata.name,
    kubernetes_manifest.nodepool_cpu_spot.manifest.metadata.name,
    kubernetes_manifest.nodepool_gpu_ondemand.manifest.metadata.name,
    kubernetes_manifest.nodepool_gpu_spot.manifest.metadata.name,
  ]
}

output "nvidia_device_plugin_status" {
  description = "Status of the NVIDIA device plugin Helm release"
  value       = helm_release.nvidia_device_plugin.status
}
