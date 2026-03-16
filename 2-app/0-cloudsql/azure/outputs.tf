output "mysql_server_id" {
  description = "ID of the MySQL Flexible Server."
  value       = var.create ? azurerm_mysql_flexible_server.default[0].id : null
}

output "mysql_server_fqdn" {
  description = "FQDN of the MySQL Flexible Server."
  value       = var.create ? azurerm_mysql_flexible_server.default[0].fqdn : null
}

output "mysql_database_name" {
  description = "Name of the initial database."
  value       = var.create ? azurerm_mysql_flexible_database.default[0].name : null
}
