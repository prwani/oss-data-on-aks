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

variable "dns_prefix" {
  description = "Optional DNS prefix for the AKS API server. Defaults to <cluster_name>-dns."
  type        = string
  default     = null
}

variable "default_agent_pool" {
  description = "Configuration for the AKS system node pool."
  type = object({
    name               = string
    vm_size            = string
    count_of           = number
    os_type            = string
    availability_zones = optional(list(string))
    node_labels        = optional(map(string))
    node_taints        = optional(list(string))
    os_disk_size_gb    = optional(number)
    upgrade_settings = optional(object({
      drain_timeout_in_minutes      = optional(number)
      node_soak_duration_in_minutes = optional(number)
      max_surge                     = string
    }))
  })
  default = {
    name               = "systempool"
    vm_size            = "Standard_D2s_v5"
    count_of           = 1
    os_type            = "Linux"
    availability_zones = []
    upgrade_settings = {
      max_surge = "10%"
    }
  }
}

variable "agent_pools" {
  description = "Additional user node pools to create for workload placement."
  type = map(object({
    name               = string
    vm_size            = string
    count_of           = number
    mode               = optional(string, "User")
    os_type            = string
    availability_zones = optional(list(string))
    node_labels        = optional(map(string))
    node_taints        = optional(list(string))
    os_disk_size_gb    = optional(number)
    upgrade_settings = optional(object({
      drain_timeout_in_minutes      = optional(number)
      node_soak_duration_in_minutes = optional(number)
      max_surge                     = string
    }))
  }))
  default = {}
}

variable "managed_identities" {
  description = "Managed identity configuration for the AKS cluster."
  type = object({
    system_assigned            = optional(bool)
    user_assigned_resource_ids = optional(list(string))
  })
  default = {
    system_assigned = true
  }
}

variable "disable_local_accounts" {
  description = "Whether to disable local AKS accounts. Keep this false unless the cluster is AAD-integrated."
  type        = bool
  default     = false
}

variable "storage_profile" {
  description = "Explicit storage driver configuration for the AKS cluster."
  type = object({
    blob_csi_driver = optional(object({
      enabled = optional(bool)
    }))
    disk_csi_driver = optional(object({
      enabled = optional(bool)
    }))
    file_csi_driver = optional(object({
      enabled = optional(bool)
    }))
    snapshot_controller = optional(object({
      enabled = optional(bool)
    }))
  })
  default = {
    disk_csi_driver = {
      enabled = true
    }
    file_csi_driver = {
      enabled = true
    }
    snapshot_controller = {
      enabled = true
    }
  }
}

variable "tags" {
  description = "Tags applied to wrapper-managed Azure resources."
  type        = map(string)
  default     = {}
}
