output "resource_group_name" {
  description = "Resource group for the Apache Kafka blueprint."
  value       = module.aks_platform.resource_group_name
}

output "cluster_name" {
  description = "AKS cluster name for the Apache Kafka blueprint."
  value       = module.aks_platform.cluster_name
}

output "kafka_node_pool_name" {
  description = "Dedicated user node pool used by the checked-in Kafka values."
  value       = "kafka"
}

output "kafka_namespace" {
  description = "Kubernetes namespace used by the Kafka blueprint."
  value       = "kafka"
}

output "get_credentials_command" {
  description = "Convenience command for connecting to the AKS cluster."
  value       = "az aks get-credentials --resource-group ${module.aks_platform.resource_group_name} --name ${module.aks_platform.cluster_name}"
}
