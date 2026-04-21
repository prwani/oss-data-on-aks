terraform {
  required_version = ">= 1.6.0"
}

provider "azurerm" {
  features {}
}

module "aks_platform" {
  source = "../../../../../platform/aks-avm/terraform"

  workload_name       = "clickhouse"
  environment_name    = "dev"
  location            = "eastus"
  resource_group_name = "rg-clickhouse-aks-dev"
  cluster_name        = "aks-clickhouse-dev"
}

# TODO: Add ClickHouse-specific storage, networking, and deployment resources.

