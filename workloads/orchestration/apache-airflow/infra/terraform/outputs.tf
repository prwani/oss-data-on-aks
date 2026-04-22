output "resource_group_name" {
  description = "Resource group for the Apache Airflow blueprint."
  value       = module.aks_platform.resource_group_name
}

output "cluster_name" {
  description = "AKS cluster name for the Apache Airflow blueprint."
  value       = module.aks_platform.cluster_name
}

output "airflow_node_pool_name" {
  description = "Dedicated AKS node pool used for Airflow components."
  value       = var.airflow_node_pool_name
}

output "airflow_namespace" {
  description = "Namespace expected by the Kubernetes manifests and Helm values."
  value       = "airflow"
}

output "get_credentials_command" {
  description = "Convenience command for connecting to the AKS cluster."
  value       = "az aks get-credentials --resource-group ${module.aks_platform.resource_group_name} --name ${module.aks_platform.cluster_name}"
}
