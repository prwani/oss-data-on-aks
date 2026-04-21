terraform {
  required_version = ">= 1.6.0"
}

provider "azurerm" {
  features {}
}

module "aks_platform" {
  source = "../../../../../platform/aks-avm/terraform"

  workload_name       = "apache-kafka"
  environment_name    = "dev"
  location            = "eastus"
  resource_group_name = "rg-apache-kafka-aks-dev"
  cluster_name        = "aks-apache-kafka-dev"
}

# TODO: Add Kafka-specific operator, storage, and listener resources.

