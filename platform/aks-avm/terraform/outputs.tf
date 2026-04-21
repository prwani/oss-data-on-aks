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
