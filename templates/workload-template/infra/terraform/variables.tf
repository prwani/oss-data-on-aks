variable "workload_name" {
  description = "Short workload name used for tags and naming."
  type        = string
  default     = "replace-me"
}

variable "workload_namespace" {
  description = "Kubernetes namespace for the workload."
  type        = string
  default     = "replace-me"
}

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
  default     = "rg-replace-me-aks-dev"
}

variable "cluster_name" {
  description = "AKS cluster name."
  type        = string
  default     = "aks-replace-me-dev"
}

variable "system_node_vm_size" {
  description = "VM size for the AKS system node pool."
  type        = string
  default     = "Standard_D2s_v5"
}

variable "system_node_count" {
  description = "Node count for the AKS system node pool."
  type        = number
  default     = 1

  validation {
    condition     = var.system_node_count >= 1
    error_message = "The system node pool must have at least one node."
  }
}

variable "workload_node_pool_name" {
  description = "Short name for the dedicated workload node pool. AKS requires 1-12 lowercase letters or digits."
  type        = string
  default     = "workload"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{0,11}$", var.workload_node_pool_name))
    error_message = "The workload node pool name must start with a letter and use 1-12 lowercase letters or digits."
  }
}

variable "workload_node_vm_size" {
  description = "VM size for the dedicated workload user pool."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "workload_node_count" {
  description = "Node count for the dedicated workload user pool. Keep this at three or higher if the workload relies on quorum or hard anti-affinity."
  type        = number
  default     = 3

  validation {
    condition     = var.workload_node_count >= 1
    error_message = "The workload node pool must have at least one node."
  }
}

variable "workload_node_os_disk_size_gb" {
  description = "OS disk size in GiB for the dedicated workload user pool."
  type        = number
  default     = 128
}

variable "tags" {
  description = "Additional tags for wrapper-managed Azure resources."
  type        = map(string)
  default     = {}
}
