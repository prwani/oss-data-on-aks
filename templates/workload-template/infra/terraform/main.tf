terraform {
  required_version = ">= 1.6.0"
}

provider "azurerm" {
  features {}
}

module "aks_platform" {
  source = "../../../../platform/aks-avm/terraform"

  workload_name       = "replace-me"
  environment_name    = "dev"
  location            = "eastus"
  resource_group_name = "rg-replace-me-dev"
  cluster_name        = "aks-replace-me-dev"
}

