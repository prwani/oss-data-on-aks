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
  tags = merge(
    {
      blueprint   = "redpanda-on-aks"
      workload    = "redpanda"
      environment = var.environment_name
    },
    var.tags
  )

  default_agent_pool = {
    name               = "systempool"
    vm_size            = var.system_pool_vm_size
    count_of           = var.system_pool_node_count
    os_type            = "Linux"
    availability_zones = var.system_pool_availability_zones
    upgrade_settings = {
      max_surge = "10%"
    }
  }

  agent_pools = {
    rpbroker = {
      name               = "rpbroker"
      vm_size            = var.broker_pool_vm_size
      count_of           = var.broker_pool_node_count
      mode               = "User"
      os_type            = "Linux"
      availability_zones = var.broker_pool_availability_zones
      node_taints = [
        "dedicated=redpanda-broker:NoSchedule"
      ]
      upgrade_settings = {
        max_surge = "33%"
      }
    }
  }
}

module "aks_platform" {
  source = "../../../../../platform/aks-avm/terraform"

  workload_name       = "redpanda"
  environment_name    = var.environment_name
  location            = var.location
  resource_group_name = var.resource_group_name
  cluster_name        = var.cluster_name
  dns_prefix          = "${var.cluster_name}-dns"
  default_agent_pool  = local.default_agent_pool
  agent_pools         = local.agent_pools
  tags                = local.tags
}
