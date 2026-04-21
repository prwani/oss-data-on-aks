terraform {
  required_version = ">= 1.6.0"
}

provider "azurerm" {
  features {}
}

module "aks_platform" {
  source = "../../../../../platform/aks-avm/terraform"

  workload_name       = "trino"
  environment_name    = "dev"
  location            = "eastus"
  resource_group_name = "rg-trino-aks-dev"
  cluster_name        = "aks-trino-dev"
}

# TODO: Add Trino-specific catalogs, ingress, and secret dependencies.

