terraform {
  required_version = ">= 1.6.0"
}

provider "azurerm" {
  features {}
}

module "aks_platform" {
  source = "../../../../../platform/aks-avm/terraform"

  workload_name       = "opensearch"
  environment_name    = "dev"
  location            = "eastus"
  resource_group_name = "rg-opensearch-aks-dev"
  cluster_name        = "aks-opensearch-dev"
}

# TODO: Add OpenSearch-specific resources and automation:
# - node pool strategy for cluster-manager and data roles
# - Azure storage and snapshot integration
# - internal exposure for API and Dashboards access path
# - Helm release automation and values management

