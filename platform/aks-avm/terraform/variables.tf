variable "aks_avm_module_version" {
  description = "Version of the AKS AVM Terraform module to validate and pin for this blueprint."
  type        = string
  default     = "0.1.0"
}

variable "workload_name" {
  description = "Short workload name used for tags and naming."
  type        = string
}

variable "environment_name" {
  description = "Environment suffix such as dev, test, or prod."
  type        = string
}

variable "location" {
  description = "Azure region for the AKS cluster."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name for the AKS cluster."
  type        = string
}

variable "cluster_name" {
  description = "AKS managed cluster name."
  type        = string
}

variable "tags" {
  description = "Tags applied to wrapper-managed Azure resources."
  type        = map(string)
  default     = {}
}
