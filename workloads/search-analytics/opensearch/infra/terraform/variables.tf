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
  description = "Resource group for the AKS cluster and supporting resources."
  type        = string
  default     = "rg-opensearch-aks-dev"
}

variable "cluster_name" {
  description = "AKS cluster name."
  type        = string
  default     = "aks-opensearch-dev"
}

variable "deploy_snapshot_storage" {
  description = "Whether to create a starter storage account and container for OpenSearch snapshots."
  type        = bool
  default     = true
}

variable "snapshot_storage_account_name" {
  description = "Optional globally unique Azure Storage account name used for snapshot artifacts. When null, Terraform generates a deterministic subscription, resource group, and cluster-specific name."
  type        = string
  default     = null

  validation {
    condition = var.snapshot_storage_account_name == null || (
      can(regex("^[a-z0-9]{3,24}$", var.snapshot_storage_account_name))
    )
    error_message = "snapshot_storage_account_name must be null or a 3-24 character lowercase alphanumeric Azure Storage account name."
  }
}

variable "snapshot_container_name" {
  description = "Blob container name for OpenSearch snapshots."
  type        = string
  default     = "opensearch-snapshots"
}

variable "tags" {
  description = "Additional tags for wrapper-managed Azure resources."
  type        = map(string)
  default     = {}
}
