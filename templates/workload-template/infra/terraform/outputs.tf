output "resource_group_name" {
  description = "Resource group for the workload blueprint."
  value       = module.aks_platform.resource_group_name
}

output "cluster_name" {
  description = "AKS cluster name for the workload blueprint."
  value       = module.aks_platform.cluster_name
}

output "workload_node_pool_name" {
  description = "Dedicated user node pool used by the workload blueprint."
  value       = var.workload_node_pool_name
}

output "workload_namespace" {
  description = "Kubernetes namespace used by the workload blueprint."
  value       = var.workload_namespace
}

output "get_credentials_command" {
  description = "Convenience command for connecting to the AKS cluster."
  value       = "az aks get-credentials --resource-group ${module.aks_platform.resource_group_name} --name ${module.aks_platform.cluster_name}"
}
