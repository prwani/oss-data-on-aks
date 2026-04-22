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
  default     = "rg-redpanda-aks-dev"
}

variable "cluster_name" {
  description = "AKS cluster name."
  type        = string
  default     = "aks-redpanda-dev"
}

variable "system_pool_vm_size" {
  description = "VM size for the AKS system pool."
  type        = string
  default     = "Standard_D4ds_v5"
}

variable "system_pool_node_count" {
  description = "Node count for the AKS system pool."
  type        = number
  default     = 1

  validation {
    condition     = var.system_pool_node_count >= 1
    error_message = "The system pool must contain at least one node."
  }
}

variable "system_pool_availability_zones" {
  description = "Availability zones for the AKS system pool. Leave empty in regions without zone support."
  type        = list(string)
  default     = []
}

variable "broker_pool_vm_size" {
  description = "VM size for the dedicated rpbroker pool. Choose an x86_64 SKU with SSE4.2 support."
  type        = string
  default     = "Standard_D8ds_v5"
}

variable "broker_pool_node_count" {
  description = "Node count for the dedicated rpbroker pool."
  type        = number
  default     = 3

  validation {
    condition     = var.broker_pool_node_count >= 3
    error_message = "The rpbroker pool must contain at least three nodes so the default Redpanda StatefulSet can keep one broker per node."
  }
}

variable "broker_pool_availability_zones" {
  description = "Availability zones for the rpbroker pool. Use one zone per node when the region supports it."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags for wrapper-managed Azure resources."
  type        = map(string)
  default     = {}
}
