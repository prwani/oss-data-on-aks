output "resource_group_name" {
  description = "Resource group for the Redpanda blueprint."
  value       = module.aks_platform.resource_group_name
}

output "cluster_name" {
  description = "AKS cluster name for the Redpanda blueprint."
  value       = module.aks_platform.cluster_name
}

output "broker_node_pool_name" {
  description = "Dedicated broker node pool created by the wrapper."
  value       = "rpbroker"
}

output "get_credentials_command" {
  description = "Convenience command for connecting to the AKS cluster."
  value       = "az aks get-credentials --resource-group ${module.aks_platform.resource_group_name} --name ${module.aks_platform.cluster_name}"
}
