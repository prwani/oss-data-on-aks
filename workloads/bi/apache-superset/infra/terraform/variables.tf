variable "environment_name" {
  description = "Environment suffix such as dev, test, or prod."
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for the deployment."
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Resource group for the AKS cluster."
  type        = string
  default     = "rg-apache-superset-aks-dev"
}

variable "cluster_name" {
  description = "AKS cluster name."
  type        = string
  default     = "aks-apache-superset-dev"
}

variable "system_node_pool_name" {
  description = "Name of the AKS system node pool."
  type        = string
  default     = "systempool"
}

variable "system_node_pool_vm_size" {
  description = "VM size for the AKS system node pool."
  type        = string
  default     = "Standard_D2s_v5"
}

variable "system_node_pool_count" {
  description = "Node count for the AKS system node pool."
  type        = number
  default     = 1
}

variable "superset_node_pool_name" {
  description = "Name of the dedicated AKS user node pool for Superset."
  type        = string
  default     = "superset"
}

variable "superset_node_pool_vm_size" {
  description = "VM size for the dedicated Superset node pool."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "superset_node_pool_count" {
  description = "Node count for the dedicated Superset node pool."
  type        = number
  default     = 3
}

variable "superset_node_pool_os_disk_size_gb" {
  description = "OS disk size in GiB for the dedicated Superset node pool."
  type        = number
  default     = 128
}

variable "tags" {
  description = "Additional tags for wrapper-managed Azure resources."
  type        = map(string)
  default     = {}
}
