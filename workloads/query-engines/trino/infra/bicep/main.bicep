targetScope = 'resourceGroup'

param clusterName string = 'aks-trino-dev'

module aksPlatform '../../../../../platform/aks-avm/bicep/main.bicep' = {
  name: 'trinoPlatform'
  params: {
    clusterName: clusterName
  }
}

// TODO: Add Trino-specific supporting resources and installation artifacts.

