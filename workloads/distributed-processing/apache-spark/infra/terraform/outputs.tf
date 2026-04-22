output "resource_group_name" {
  description = "Resource group for the Apache Spark blueprint."
  value       = module.aks_platform.resource_group_name
}

output "cluster_name" {
  description = "AKS cluster name for the Apache Spark blueprint."
  value       = module.aks_platform.cluster_name
}

output "spark_node_pool_name" {
  description = "Dedicated AKS node pool used for Spark drivers and executors."
  value       = var.spark_node_pool_name
}

output "spark_namespace" {
  description = "Namespace expected by the Spark workload manifests."
  value       = "spark"
}

output "spark_operator_namespace" {
  description = "Namespace expected by the Spark operator Helm release."
  value       = "spark-operator"
}

output "get_credentials_command" {
  description = "Convenience command for connecting to the AKS cluster."
  value       = "az aks get-credentials --resource-group ${module.aks_platform.resource_group_name} --name ${module.aks_platform.cluster_name}"
}
