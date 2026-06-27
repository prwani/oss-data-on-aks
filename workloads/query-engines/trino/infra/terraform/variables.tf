variable "environment_name" {
  description = "Environment suffix such as dev, test, or prod."
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for the deployment."
  type        = string
  default     = "swedencentral"
}

variable "resource_group_name" {
  description = "Resource group for the AKS cluster."
  type        = string
  default     = "rg-trino-aks-dev"
}

variable "cluster_name" {
  description = "AKS cluster name."
  type        = string
  default     = "aks-trino-dev"
}

variable "lakehouse_storage_account_name" {
  description = "ADLS Gen2 storage account name. Leave null to generate a deterministic name."
  type        = string
  default     = null
}

variable "lakehouse_file_system_name" {
  description = "ADLS Gen2 file system/container for Iceberg table data."
  type        = string
  default     = "lakehouse"
}

variable "lakehouse_identity_name" {
  description = "User-assigned managed identity name used by Trino and the Iceberg REST catalog for ADLS Gen2 access."
  type        = string
  default     = null
}

variable "polaris_postgresql_server_name" {
  description = "PostgreSQL Flexible Server name for Apache Polaris metadata. Leave null to generate a deterministic name."
  type        = string
  default     = null
}

variable "polaris_postgresql_database_name" {
  description = "PostgreSQL database name for Apache Polaris metadata."
  type        = string
  default     = "polaris"
}

variable "polaris_postgresql_admin_login" {
  description = "PostgreSQL administrator login for Apache Polaris metadata."
  type        = string
  default     = "polarisadmin"
}

variable "polaris_postgresql_admin_password" {
  description = "PostgreSQL administrator password for Apache Polaris metadata. Pass at deployment time; do not commit it."
  type        = string
  sensitive   = true
}

variable "polaris_postgresql_sku_name" {
  description = "PostgreSQL Flexible Server SKU for Apache Polaris metadata."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "polaris_postgresql_storage_mb" {
  description = "PostgreSQL Flexible Server storage size in MiB."
  type        = number
  default     = 32768
}

variable "system_pool_vm_size" {
  description = "VM size for the system node pool."
  type        = string
  default     = "Standard_D2s_v6"
}

variable "system_pool_node_count" {
  description = "Node count for the system node pool."
  type        = number
  default     = 1
}

variable "trino_node_pool_vm_size" {
  description = "VM size for the dedicated Trino user pool. Prefer local SSD/NVMe-capable SKUs for worker spill."
  type        = string
  default     = "Standard_L8s_v3"
}

variable "trino_node_pool_node_count" {
  description = "Node count for the dedicated Trino user pool."
  type        = number
  default     = 3
}

variable "catalog_node_pool_vm_size" {
  description = "VM size for the Iceberg REST catalog user pool."
  type        = string
  default     = "Standard_D4s_v6"
}

variable "catalog_node_pool_node_count" {
  description = "Node count for the Iceberg REST catalog user pool."
  type        = number
  default     = 2
}

variable "tags" {
  description = "Additional tags for wrapper-managed Azure resources."
  type        = map(string)
  default     = {}
}
