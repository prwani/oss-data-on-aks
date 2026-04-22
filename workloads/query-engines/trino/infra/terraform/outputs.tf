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

output "namespace_name" {
  description = "Kubernetes namespace used by the Trino workload."
  value       = "trino"
}

output "get_credentials_command" {
  description = "Convenience command for connecting to the AKS cluster."
  value       = "az aks get-credentials --resource-group ${module.aks_platform.resource_group_name} --name ${module.aks_platform.cluster_name}"
}
