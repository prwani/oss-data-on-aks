terraform {
  required_version = ">= 1.11.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.4"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.46.0, < 5.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}

locals {
  tags = merge(
    {
      blueprint   = "opensearch-on-aks"
      workload    = "opensearch"
      environment = var.environment_name
    },
    var.tags
  )

  default_agent_pool = {
    name               = "systempool"
    vm_size            = "Standard_D2s_v5"
    count_of           = 1
    os_type            = "Linux"
    availability_zones = []
    upgrade_settings = {
      max_surge = "10%"
    }
  }

  agent_pools = {
    osmgr = {
      name               = "osmgr"
      vm_size            = "Standard_D4s_v5"
      count_of           = 3
      mode               = "User"
      os_type            = "Linux"
      availability_zones = []
      node_taints = [
        "dedicated=opensearch-manager:NoSchedule"
      ]
      upgrade_settings = {
        max_surge = "10%"
      }
    }
    osdata = {
      name               = "osdata"
      vm_size            = "Standard_D4s_v5"
      count_of           = 3
      mode               = "User"
      os_type            = "Linux"
      availability_zones = []
      node_taints = [
        "dedicated=opensearch-data:NoSchedule"
      ]
      upgrade_settings = {
        max_surge = "10%"
      }
    }
  }
}

data "azurerm_resource_group" "aks_platform" {
  name       = module.aks_platform.resource_group_name
  depends_on = [module.aks_platform]
}

module "aks_platform" {
  source = "../../../../../platform/aks-avm/terraform"

  workload_name       = "opensearch"
  environment_name    = var.environment_name
  location            = var.location
  resource_group_name = var.resource_group_name
  cluster_name        = var.cluster_name
  dns_prefix          = "${var.cluster_name}-dns"
  default_agent_pool  = local.default_agent_pool
  agent_pools         = local.agent_pools
  tags                = local.tags
}

resource "azapi_resource" "snapshot_storage" {
  count = var.deploy_snapshot_storage ? 1 : 0

  type      = "Microsoft.Storage/storageAccounts@2023-05-01"
  name      = var.snapshot_storage_account_name
  parent_id = data.azurerm_resource_group.aks_platform.id
  location  = module.aks_platform.location
  tags      = local.tags
  body = {
    kind = "StorageV2"
    sku = {
      name = "Standard_LRS"
    }
    properties = {
      allowBlobPublicAccess    = false
      minimumTlsVersion        = "TLS1_2"
      supportsHttpsTrafficOnly = true
    }
  }
}

resource "azapi_resource" "snapshot_blob_service" {
  count = var.deploy_snapshot_storage ? 1 : 0

  type      = "Microsoft.Storage/storageAccounts/blobServices@2023-05-01"
  name      = "default"
  parent_id = azapi_resource.snapshot_storage[0].id
  body = {
    properties = {}
  }
}

resource "azapi_resource" "snapshot_container" {
  count = var.deploy_snapshot_storage ? 1 : 0

  type      = "Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01"
  name      = var.snapshot_container_name
  parent_id = azapi_resource.snapshot_blob_service[0].id
  body = {
    properties = {
      publicAccess = "None"
    }
  }
}
