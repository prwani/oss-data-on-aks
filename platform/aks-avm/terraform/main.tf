module "aks_baseline" {
  source  = "Azure/avm-res-containerservice-managedcluster/azurerm"
  version = var.aks_avm_module_version

  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name

  # Extend this module call with the tested AVM inputs for:
  # - node pools and zoning
  # - networking and private access
  # - managed identity and RBAC
  # - monitoring and policy add-ons
  # - workload-specific storage classes or supporting resources
}

