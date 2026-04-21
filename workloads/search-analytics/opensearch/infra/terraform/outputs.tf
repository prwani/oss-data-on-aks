output "resource_group_name" {
  description = "Resource group for the OpenSearch blueprint."
  value       = module.aks_platform.resource_group_name
}

output "cluster_name" {
  description = "AKS cluster name for the OpenSearch blueprint."
  value       = module.aks_platform.cluster_name
}

output "snapshot_storage_account_name" {
  description = "Storage account created for snapshot use, if enabled."
  value       = try(azurerm_storage_account.snapshot[0].name, null)
}

output "snapshot_container_name" {
  description = "Blob container created for snapshot use, if enabled."
  value       = try(azurerm_storage_container.snapshot[0].name, null)
}

output "get_credentials_command" {
  description = "Convenience command for connecting to the AKS cluster."
  value       = "az aks get-credentials --resource-group ${module.aks_platform.resource_group_name} --name ${module.aks_platform.cluster_name}"
}
