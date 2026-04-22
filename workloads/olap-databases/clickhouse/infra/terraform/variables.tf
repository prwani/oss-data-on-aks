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
  default     = "rg-clickhouse-aks-dev"
}

variable "cluster_name" {
  description = "AKS cluster name."
  type        = string
  default     = "aks-clickhouse-dev"
}

variable "system_pool_vm_size" {
  description = "VM size for the system node pool."
  type        = string
  default     = "Standard_D2s_v5"
}

variable "system_pool_node_count" {
  description = "Node count for the system node pool."
  type        = number
  default     = 1
}

variable "clickhouse_node_pool_vm_size" {
  description = "VM size for the dedicated ClickHouse user pool."
  type        = string
  default     = "Standard_E8ds_v5"
}

variable "clickhouse_node_pool_node_count" {
  description = "Node count for the dedicated ClickHouse user pool."
  type        = number
  default     = 3
}

variable "tags" {
  description = "Additional tags for wrapper-managed Azure resources."
  type        = map(string)
  default     = {}
}
