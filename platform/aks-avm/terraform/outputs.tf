output "resource_group_name" {
  description = "Resource group name created by the wrapper."
  value       = azurerm_resource_group.this.name
}

output "location" {
  description = "Azure region used by the wrapper."
  value       = azurerm_resource_group.this.location
}

output "cluster_name" {
  description = "AKS cluster name requested from the wrapper."
  value       = var.cluster_name
}

output "cluster_resource_id" {
  description = "AKS managed cluster resource ID."
  value       = module.aks_baseline.resource_id
}

output "cluster_oidc_issuer_enabled" {
  description = "Whether the wrapper enabled the AKS OIDC issuer profile."
  value       = var.enable_oidc_issuer
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the AKS cluster when the OIDC issuer profile is enabled."
  value       = try(module.aks_baseline.oidc_issuer_profile_issuer_url, null)
}

output "cluster_workload_identity_enabled" {
  description = "Whether the wrapper enabled AKS workload identity."
  value       = var.enable_workload_identity
}

output "cluster_identity_system_assigned_enabled" {
  description = "Whether the cluster is configured with a system-assigned managed identity."
  value       = try(var.managed_identities.system_assigned, false)
}

output "cluster_user_assigned_identity_resource_ids" {
  description = "User-assigned managed identity resource IDs requested for the cluster."
  value       = try(var.managed_identities.user_assigned_resource_ids, [])
}

output "cluster_identity_principal_id" {
  description = "Principal ID of the cluster-managed identity when available."
  value       = try(module.aks_baseline.identity_principal_id, null)
}

output "cluster_identity_tenant_id" {
  description = "Tenant ID of the cluster-managed identity when available."
  value       = try(module.aks_baseline.identity_tenant_id, null)
}

output "node_resource_group_name" {
  description = "Name of the AKS node resource group."
  value       = try(module.aks_baseline.node_resource_group_name, null)
}

output "kubelet_identity" {
  description = "Kubelet identity object for the AKS cluster."
  value       = try(module.aks_baseline.kubelet_identity, null)
}

output "kubelet_identity_client_id" {
  description = "Client ID of the kubelet managed identity."
  value       = try(module.aks_baseline.kubelet_identity.clientId, null)
}

output "kubelet_identity_object_id" {
  description = "Object ID of the kubelet managed identity."
  value       = try(module.aks_baseline.kubelet_identity.objectId, null)
}

output "kubelet_identity_resource_id" {
  description = "Resource ID of the kubelet managed identity."
  value       = try(module.aks_baseline.kubelet_identity.resourceId, null)
}
