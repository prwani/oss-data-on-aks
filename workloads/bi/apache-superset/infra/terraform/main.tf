terraform {
  required_version = ">= 1.6.0"
}

provider "azurerm" {
  features {}
}

module "aks_platform" {
  source = "../../../../../platform/aks-avm/terraform"

  workload_name       = "apache-superset"
  environment_name    = "dev"
  location            = "eastus"
  resource_group_name = "rg-apache-superset-aks-dev"
  cluster_name        = "aks-apache-superset-dev"
}

# TODO: Add Superset-specific dependencies, secrets, and deployment resources.

