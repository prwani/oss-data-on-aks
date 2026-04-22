output "resource_group_name" {
  description = "Resource group for the OpenSearch blueprint."
  value       = module.aks_platform.resource_group_name
}

output "cluster_name" {
  description = "AKS cluster name for the OpenSearch blueprint."
  value       = module.aks_platform.cluster_name
}

output "cluster_resource_id" {
  description = "AKS cluster resource ID for the OpenSearch blueprint."
  value       = module.aks_platform.cluster_resource_id
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the AKS cluster."
  value       = module.aks_platform.cluster_oidc_issuer_url
}

output "cluster_workload_identity_enabled" {
  description = "Whether the OpenSearch blueprint enabled AKS workload identity."
  value       = module.aks_platform.cluster_workload_identity_enabled
}

output "snapshot_storage_account_name" {
  description = "Storage account created for snapshot use, if enabled."
  value       = try(azapi_resource.snapshot_storage[0].name, null)
}

output "snapshot_storage_account_id" {
  description = "Storage account resource ID created for snapshot use, if enabled."
  value       = try(azapi_resource.snapshot_storage[0].id, null)
}

output "snapshot_container_name" {
  description = "Blob container created for snapshot use, if enabled."
  value       = try(azapi_resource.snapshot_container[0].name, null)
}

output "snapshot_container_id" {
  description = "Blob container resource ID created for snapshot use, if enabled."
  value       = try(azapi_resource.snapshot_container[0].id, null)
}

output "snapshot_managed_identity_client_id" {
  description = "Client ID of the user-assigned managed identity used for OpenSearch snapshots."
  value       = try(azurerm_user_assigned_identity.snapshot[0].client_id, null)
}

output "snapshot_managed_identity_principal_id" {
  description = "Principal ID of the user-assigned managed identity used for OpenSearch snapshots."
  value       = try(azurerm_user_assigned_identity.snapshot[0].principal_id, null)
}

output "snapshot_managed_identity_resource_id" {
  description = "Resource ID of the user-assigned managed identity used for OpenSearch snapshots."
  value       = try(azurerm_user_assigned_identity.snapshot[0].id, null)
}

output "snapshot_manager_service_account_name" {
  description = "Kubernetes service account name created by the manager release for snapshot access."
  value       = local.snapshot_manager_service_account_name
}

output "snapshot_manager_service_account_subject" {
  description = "Federated identity subject bound to the manager snapshot service account."
  value       = local.snapshot_manager_service_account_subject
}

output "snapshot_data_service_account_name" {
  description = "Kubernetes service account name created by the data release for snapshot access."
  value       = local.snapshot_data_service_account_name
}

output "snapshot_data_service_account_subject" {
  description = "Federated identity subject bound to the data snapshot service account."
  value       = local.snapshot_data_service_account_subject
}

output "get_credentials_command" {
  description = "Convenience command for connecting to the AKS cluster."
  value       = "az aks get-credentials --resource-group ${module.aks_platform.resource_group_name} --name ${module.aks_platform.cluster_name}"
}
