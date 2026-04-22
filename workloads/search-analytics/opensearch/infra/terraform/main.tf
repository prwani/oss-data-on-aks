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

  snapshot_service_account_namespace       = "opensearch"
  snapshot_manager_service_account_name    = "opensearch-manager-snapshots"
  snapshot_data_service_account_name       = "opensearch-data-snapshots"
  snapshot_manager_service_account_subject = "system:serviceaccount:${local.snapshot_service_account_namespace}:${local.snapshot_manager_service_account_name}"
  snapshot_data_service_account_subject    = "system:serviceaccount:${local.snapshot_service_account_namespace}:${local.snapshot_data_service_account_name}"
  snapshot_managed_identity_name           = "id-opensearch-snapshots-${var.environment_name}"
}

data "azurerm_resource_group" "aks_platform" {
  name       = module.aks_platform.resource_group_name
  depends_on = [module.aks_platform]
}

module "aks_platform" {
  source = "../../../../../platform/aks-avm/terraform"

  workload_name            = "opensearch"
  environment_name         = var.environment_name
  location                 = var.location
  resource_group_name      = var.resource_group_name
  cluster_name             = var.cluster_name
  dns_prefix               = "${var.cluster_name}-dns"
  enable_oidc_issuer       = true
  enable_workload_identity = true
  default_agent_pool       = local.default_agent_pool
  agent_pools              = local.agent_pools
  tags                     = local.tags
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
      allowBlobPublicAccess        = false
      allowSharedKeyAccess         = false
      defaultToOAuthAuthentication = true
      minimumTlsVersion            = "TLS1_2"
      supportsHttpsTrafficOnly     = true
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

resource "azurerm_user_assigned_identity" "snapshot" {
  count = var.deploy_snapshot_storage ? 1 : 0

  location            = module.aks_platform.location
  name                = local.snapshot_managed_identity_name
  resource_group_name = module.aks_platform.resource_group_name
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "snapshot_manager" {
  count = var.deploy_snapshot_storage ? 1 : 0

  name                = "fic-opensearch-manager-snapshots-${var.environment_name}"
  resource_group_name = module.aks_platform.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.aks_platform.cluster_oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.snapshot[0].id
  subject             = local.snapshot_manager_service_account_subject
}

resource "azurerm_federated_identity_credential" "snapshot_data" {
  count = var.deploy_snapshot_storage ? 1 : 0

  name                = "fic-opensearch-data-snapshots-${var.environment_name}"
  resource_group_name = module.aks_platform.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.aks_platform.cluster_oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.snapshot[0].id
  subject             = local.snapshot_data_service_account_subject
}

resource "azurerm_role_assignment" "snapshot_container_blob_data_contributor" {
  count = var.deploy_snapshot_storage ? 1 : 0

  scope                = azapi_resource.snapshot_container[0].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.snapshot[0].principal_id
  principal_type       = "ServicePrincipal"
}
