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
      blueprint   = "apache-spark-on-aks"
      workload    = "apache-spark"
      environment = var.environment_name
    },
    var.tags
  )

  default_agent_pool = {
    name               = var.system_node_pool_name
    vm_size            = var.system_node_pool_vm_size
    count_of           = var.system_node_pool_count
    os_type            = "Linux"
    availability_zones = []
    upgrade_settings = {
      max_surge = "10%"
    }
  }

  agent_pools = {
    spark = {
      name               = var.spark_node_pool_name
      vm_size            = var.spark_node_pool_vm_size
      count_of           = var.spark_node_pool_count
      mode               = "User"
      os_type            = "Linux"
      availability_zones = []
      node_labels = {
        workload = "apache-spark"
      }
      node_taints = [
        "dedicated=spark:NoSchedule"
      ]
      os_disk_size_gb = var.spark_node_pool_os_disk_size_gb
      upgrade_settings = {
        max_surge = "10%"
      }
    }
  }
}

module "aks_platform" {
  source = "../../../../../platform/aks-avm/terraform"

  workload_name       = "apache-spark"
  environment_name    = var.environment_name
  location            = var.location
  resource_group_name = var.resource_group_name
  cluster_name        = var.cluster_name
  dns_prefix          = "${var.cluster_name}-dns"
  default_agent_pool  = local.default_agent_pool
  agent_pools         = local.agent_pools
  tags                = local.tags
}
