output "resource_group_name" {
  description = "Resource group for the Apache Flink blueprint."
  value       = module.aks_platform.resource_group_name
}

output "cluster_name" {
  description = "AKS cluster name for the Apache Flink blueprint."
  value       = module.aks_platform.cluster_name
}

output "flink_node_pool_name" {
  description = "Dedicated AKS node pool used for Flink JobManagers and TaskManagers."
  value       = var.flink_node_pool_name
}

output "flink_namespace" {
  description = "Namespace expected by the Flink workload manifests."
  value       = "flink"
}

output "flink_operator_namespace" {
  description = "Namespace expected by the Flink operator Helm release."
  value       = "flink-operator"
}

output "get_credentials_command" {
  description = "Convenience command for connecting to the AKS cluster."
  value       = "az aks get-credentials --resource-group ${module.aks_platform.resource_group_name} --name ${module.aks_platform.cluster_name}"
}
