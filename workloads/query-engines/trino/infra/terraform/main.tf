terraform {
  required_version = ">= 1.11.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.46.0, < 5.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  lakehouse_storage_account_name = coalesce(var.lakehouse_storage_account_name, "st${substr(md5("${var.resource_group_name}${var.cluster_name}lakehouse"), 0, 18)}")
  lakehouse_identity_name        = coalesce(var.lakehouse_identity_name, "${var.cluster_name}-lakehouse-uami")
  polaris_postgresql_server_name = coalesce(var.polaris_postgresql_server_name, "psql-${substr(md5("${var.resource_group_name}${var.cluster_name}polaris"), 0, 12)}")

  tags = merge(
    {
      blueprint   = "trino-on-aks"
      workload    = "trino"
      environment = var.environment_name
    },
    var.tags
  )

  default_agent_pool = {
    name               = "systempool"
    vm_size            = var.system_pool_vm_size
    count_of           = var.system_pool_node_count
    os_type            = "Linux"
    availability_zones = []
    upgrade_settings = {
      max_surge = "10%"
    }
  }

  agent_pools = {
    trino = {
      name               = "trino"
      vm_size            = var.trino_node_pool_vm_size
      count_of           = var.trino_node_pool_node_count
      mode               = "User"
      os_type            = "Linux"
      availability_zones = []
      node_taints = [
        "dedicated=trino:NoSchedule"
      ]
      upgrade_settings = {
        max_surge = "10%"
      }
    }

    catalog = {
      name               = "catalog"
      vm_size            = var.catalog_node_pool_vm_size
      count_of           = var.catalog_node_pool_node_count
      mode               = "User"
      os_type            = "Linux"
      availability_zones = []
      node_taints = [
        "dedicated=catalog:NoSchedule"
      ]
      upgrade_settings = {
        max_surge = "10%"
      }
    }
  }
}

resource "azurerm_user_assigned_identity" "lakehouse" {
  name                = local.lakehouse_identity_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.tags

  depends_on = [module.aks_platform]
}

resource "azurerm_storage_account" "lakehouse" {
  name                            = local.lakehouse_storage_account_name
  location                        = var.location
  resource_group_name             = var.resource_group_name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  allow_nested_items_to_be_public = false
  default_to_oauth_authentication = true
  https_traffic_only_enabled      = true
  is_hns_enabled                  = true
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false
  tags                            = local.tags

  depends_on = [module.aks_platform]
}

resource "azurerm_storage_container" "lakehouse" {
  name                  = var.lakehouse_file_system_name
  storage_account_id    = azurerm_storage_account.lakehouse.id
  container_access_type = "private"
}

resource "azurerm_role_assignment" "lakehouse_blob_data_contributor" {
  scope                = azurerm_storage_account.lakehouse.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.lakehouse.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_postgresql_flexible_server" "polaris" {
  name                          = local.polaris_postgresql_server_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  administrator_login           = var.polaris_postgresql_admin_login
  administrator_password        = var.polaris_postgresql_admin_password
  public_network_access_enabled = true
  sku_name                      = var.polaris_postgresql_sku_name
  storage_mb                    = var.polaris_postgresql_storage_mb
  version                       = "16"
  tags                          = local.tags

  authentication {
    active_directory_auth_enabled = false
    password_auth_enabled         = true
  }

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  depends_on = [module.aks_platform]
}

resource "azurerm_postgresql_flexible_server_database" "polaris" {
  name      = var.polaris_postgresql_database_name
  server_id = azurerm_postgresql_flexible_server.polaris.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.polaris.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

module "aks_platform" {
  source = "../../../../../platform/aks-avm/terraform"

  workload_name             = "trino"
  environment_name          = var.environment_name
  location                  = var.location
  resource_group_name       = var.resource_group_name
  cluster_name              = var.cluster_name
  dns_prefix                = "${var.cluster_name}-dns"
  default_agent_pool        = local.default_agent_pool
  agent_pools               = local.agent_pools
  enable_oidc_issuer       = true
  enable_workload_identity = true
  tags                      = local.tags
}

resource "azurerm_federated_identity_credential" "trino_service_account" {
  name                = "trino-service-account"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.lakehouse.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.aks_platform.cluster_oidc_issuer_url
  subject             = "system:serviceaccount:trino:trino"
}

resource "azurerm_federated_identity_credential" "catalog_service_account" {
  name                = "iceberg-rest-catalog-service-account"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.lakehouse.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.aks_platform.cluster_oidc_issuer_url
  subject             = "system:serviceaccount:iceberg-catalog:polaris"

  depends_on = [azurerm_federated_identity_credential.trino_service_account]
}
