locals {
  dns_prefix = coalesce(var.dns_prefix, "${var.cluster_name}-dns")
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location

  tags = merge(var.tags, {
    workload    = var.workload_name
    environment = var.environment_name
  })
}

module "aks_baseline" {
  source  = "Azure/avm-res-containerservice-managedcluster/azurerm"
  version = "0.5.3"

  name      = var.cluster_name
  location  = azurerm_resource_group.this.location
  parent_id = azurerm_resource_group.this.id

  dns_prefix             = local.dns_prefix
  managed_identities     = var.managed_identities
  oidc_issuer_profile    = var.enable_oidc_issuer ? { enabled = true } : null
  security_profile       = var.enable_workload_identity ? { workload_identity = { enabled = true } } : null
  default_agent_pool     = var.default_agent_pool
  agent_pools            = var.agent_pools
  disable_local_accounts = var.disable_local_accounts
  storage_profile        = var.storage_profile

  tags = merge(var.tags, {
    workload    = var.workload_name
    environment = var.environment_name
  })
}
