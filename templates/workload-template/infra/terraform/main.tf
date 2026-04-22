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
      blueprint   = "${var.workload_name}-on-aks"
      workload    = var.workload_name
      environment = var.environment_name
    },
    var.tags
  )

  default_agent_pool = {
    name               = "systempool"
    vm_size            = var.system_node_vm_size
    count_of           = var.system_node_count
    os_type            = "Linux"
    availability_zones = []
    upgrade_settings = {
      max_surge = "10%"
    }
  }

  agent_pools = {
    workload = {
      name               = var.workload_node_pool_name
      vm_size            = var.workload_node_vm_size
      count_of           = var.workload_node_count
      mode               = "User"
      os_type            = "Linux"
      availability_zones = []
      node_labels = {
        workload = var.workload_name
      }
      node_taints = [
        "dedicated=${var.workload_node_pool_name}:NoSchedule"
      ]
      os_disk_size_gb = var.workload_node_os_disk_size_gb
      upgrade_settings = {
        max_surge = "10%"
      }
    }
  }
}

module "aks_platform" {
  source = "../../../../platform/aks-avm/terraform"

  workload_name       = var.workload_name
  environment_name    = var.environment_name
  location            = var.location
  resource_group_name = var.resource_group_name
  cluster_name        = var.cluster_name
  dns_prefix          = "${var.cluster_name}-dns"
  default_agent_pool  = local.default_agent_pool
  agent_pools         = local.agent_pools
  tags                = local.tags
}
