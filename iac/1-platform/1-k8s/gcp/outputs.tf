output "cluster_endpoints" {
  description = "Map of cluster endpoints by cluster name (created or looked up)"
  value = {
    for name, cluster in local.gke_clusters :
    name => cluster.endpoint
  }
}

output "cluster_ca_certificates" {
  description = "Map of cluster CA certificates by cluster name"
  value = {
    for name, cluster in local.gke_clusters :
    name => cluster.master_auth[0].cluster_ca_certificate
  }
}

output "dns_config_configured" {
  description = "DNS config applied per cluster: dns_scope (CLUSTER_SCOPE or VPC_SCOPE) and dns_domain (additive VPC domain). Defaults set in terragrunt."
  value = {
    for name, cluster in local.gke_clusters :
    name => length(cluster.dns_config) > 0 ? {
      dns_scope  = cluster.dns_config[0].cluster_dns_scope
      dns_domain = cluster.dns_config[0].additive_vpc_scope_dns_domain
    } : null
  }
}

output "release_channel_configured" {
  description = "GKE release channel per cluster (REGULAR|RAPID|STABLE). From k8s.release_channel when cloud_provider=gcp."
  value = {
    for name, cluster in local.gke_clusters :
    name => cluster.release_channel[0].channel
  }
}
