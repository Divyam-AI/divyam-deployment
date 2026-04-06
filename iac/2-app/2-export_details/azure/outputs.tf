output "provider_yaml_path" {
  description = "Absolute path to the generated provider.yaml file."
  value       = local_file.provider_yaml.filename
}

output "provider_yaml_content" {
  description = "Content of the generated provider.yaml file."
  value       = local.provider_yaml_content
  sensitive   = true
}
