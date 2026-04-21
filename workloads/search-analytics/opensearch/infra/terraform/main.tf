terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  tags = merge(
    {
      blueprint   = "opensearch-on-aks"
      workload    = "opensearch"
      environment = var.environment_name
    },
    var.tags
  )
}

module "aks_platform" {
  source = "../../../../../platform/aks-avm/terraform"

  aks_avm_module_version = var.aks_avm_module_version
  workload_name          = "opensearch"
  environment_name       = var.environment_name
  location               = var.location
  resource_group_name    = var.resource_group_name
  cluster_name           = var.cluster_name
  tags                   = local.tags
}

resource "azurerm_storage_account" "snapshot" {
  count = var.deploy_snapshot_storage ? 1 : 0

  name                     = var.snapshot_storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  min_tls_version          = "TLS1_2"

  allow_nested_items_to_be_public = false

  tags = local.tags
}

resource "azurerm_storage_container" "snapshot" {
  count = var.deploy_snapshot_storage ? 1 : 0

  name                  = var.snapshot_container_name
  storage_account_name  = azurerm_storage_account.snapshot[0].name
  container_access_type = "private"
}
