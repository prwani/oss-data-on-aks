terraform {
  required_version = ">= 1.6.0"
}

provider "azurerm" {
  features {}
}

module "aks_platform" {
  source = "../../../../../platform/aks-avm/terraform"

  workload_name       = "apache-spark"
  environment_name    = "dev"
  location            = "eastus"
  resource_group_name = "rg-apache-spark-aks-dev"
  cluster_name        = "aks-apache-spark-dev"
}

# TODO: Add Spark-specific runtime, identity, and deployment resources.

