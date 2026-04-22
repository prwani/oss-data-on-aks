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
  default     = "rg-apache-kafka-aks-dev"
}

variable "cluster_name" {
  description = "AKS cluster name."
  type        = string
  default     = "aks-apache-kafka-dev"
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

variable "kafka_node_vm_size" {
  description = "VM size for the dedicated kafka user pool."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "kafka_node_count" {
  description = "Node count for the dedicated kafka user pool. Keep this at three or higher so the default controller and broker anti-affinity rules can place all pods."
  type        = number
  default     = 3

  validation {
    condition     = var.kafka_node_count >= 3
    error_message = "The kafka node pool must have at least three nodes for the checked-in Helm values."
  }
}

variable "kafka_node_os_disk_size_gb" {
  description = "OS disk size in GiB for the dedicated kafka user pool."
  type        = number
  default     = 128
}

variable "tags" {
  description = "Additional tags for wrapper-managed Azure resources."
  type        = map(string)
  default     = {}
}
