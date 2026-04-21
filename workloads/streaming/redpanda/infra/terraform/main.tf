terraform {
  required_version = ">= 1.6.0"
}

provider "azurerm" {
  features {}
}

module "aks_platform" {
  source = "../../../../../platform/aks-avm/terraform"

  workload_name       = "redpanda"
  environment_name    = "dev"
  location            = "eastus"
  resource_group_name = "rg-redpanda-aks-dev"
  cluster_name        = "aks-redpanda-dev"
}

# TODO: Add Redpanda-specific storage, listener, and operator resources.

