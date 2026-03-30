output "env_yaml_path" {
  description = "Absolute path to the generated env.yaml file."
  value       = local_file.env_yaml.filename
}

output "env_yaml_content" {
  description = "Content of the generated env.yaml file."
  value       = local.env_yaml_content
}
