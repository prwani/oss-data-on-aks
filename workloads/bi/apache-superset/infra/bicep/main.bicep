targetScope = 'resourceGroup'

param clusterName string = 'aks-apache-superset-dev'

module aksPlatform '../../../../../platform/aks-avm/bicep/main.bicep' = {
  name: 'apacheSupersetPlatform'
  params: {
    clusterName: clusterName
  }
}

// TODO: Add Superset-specific supporting resources and installation artifacts.

