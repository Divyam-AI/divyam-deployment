output "helm_releases" {
  description = "Deployed Helm releases"
  value = {
    for k, rel in helm_release.divyam_deploy :
    k => { name : rel.name, namespace : rel.namespace, version : rel.version }
  }
}
