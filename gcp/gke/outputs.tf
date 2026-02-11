output "cluster_endpoints" {
  description = "Map of cluster endpoints by cluster name"
  value = {
    for name, cluster in google_container_cluster.gke_cluster :
    name => cluster.endpoint
  }
}

output "cluster_ca_certificates" {
  description = "Map of cluster CA certificates by cluster name"
  value = {
    for cluster in google_container_cluster.gke_cluster :
    cluster.name => cluster.master_auth[0].cluster_ca_certificate
  }
}