output "resource_group_name" {
  description = "Resource group for the Trino blueprint."
  value       = module.aks_platform.resource_group_name
}

output "cluster_name" {
  description = "AKS cluster name for the Trino blueprint."
  value       = module.aks_platform.cluster_name
}

output "dedicated_node_pool_name" {
  description = "Dedicated user pool name for Trino placement."
  value       = "trino"
}

output "catalog_node_pool_name" {
  description = "Dedicated user pool name for Iceberg REST catalog placement."
  value       = "catalog"
}

output "namespace_name" {
  description = "Kubernetes namespace used by the Trino workload."
  value       = "trino"
}

output "get_credentials_command" {
  description = "Convenience command for connecting to the AKS cluster."
  value       = "az aks get-credentials --resource-group ${module.aks_platform.resource_group_name} --name ${module.aks_platform.cluster_name}"
}

output "lakehouse_storage_account_name" {
  description = "ADLS Gen2 storage account for Iceberg table data."
  value       = azurerm_storage_account.lakehouse.name
}

output "lakehouse_file_system_name" {
  description = "ADLS Gen2 file system/container for Iceberg table data."
  value       = azurerm_storage_container.lakehouse.name
}

output "lakehouse_warehouse_uri" {
  description = "ADLS Gen2 warehouse URI for Iceberg tables."
  value       = "abfss://${azurerm_storage_container.lakehouse.name}@${azurerm_storage_account.lakehouse.name}.dfs.core.windows.net/iceberg/warehouse"
}

output "lakehouse_identity_client_id" {
  description = "Client ID for the user-assigned managed identity used by Trino and the Iceberg REST catalog."
  value       = azurerm_user_assigned_identity.lakehouse.client_id
}

output "lakehouse_identity_resource_id" {
  description = "Resource ID for the user-assigned managed identity used by Trino and the Iceberg REST catalog."
  value       = azurerm_user_assigned_identity.lakehouse.id
}

output "polaris_postgresql_server_name" {
  description = "PostgreSQL Flexible Server name for Apache Polaris metadata."
  value       = azurerm_postgresql_flexible_server.polaris.name
}

output "polaris_postgresql_database_name" {
  description = "PostgreSQL database name for Apache Polaris metadata."
  value       = azurerm_postgresql_flexible_server_database.polaris.name
}

output "polaris_postgresql_host" {
  description = "PostgreSQL Flexible Server host for Apache Polaris metadata."
  value       = azurerm_postgresql_flexible_server.polaris.fqdn
}

output "polaris_postgresql_jdbc_url" {
  description = "JDBC URL for Apache Polaris metadata."
  value       = "jdbc:postgresql://${azurerm_postgresql_flexible_server.polaris.fqdn}:5432/${azurerm_postgresql_flexible_server_database.polaris.name}?sslmode=require"
}

output "polaris_postgresql_admin_login" {
  description = "PostgreSQL administrator login for Apache Polaris metadata."
  value       = var.polaris_postgresql_admin_login
}
