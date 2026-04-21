terraform {
  required_version = ">= 1.6.0"
}

provider "azurerm" {
  features {}
}

module "aks_platform" {
  source = "../../../../../platform/aks-avm/terraform"

  workload_name       = "apache-airflow"
  environment_name    = "dev"
  location            = "eastus"
  resource_group_name = "rg-apache-airflow-aks-dev"
  cluster_name        = "aks-apache-airflow-dev"
}

# TODO: Add Airflow-specific dependencies, secrets, and deployment resources.

