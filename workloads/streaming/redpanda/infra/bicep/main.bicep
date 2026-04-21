targetScope = 'resourceGroup'

param clusterName string = 'aks-redpanda-dev'

module aksPlatform '../../../../../platform/aks-avm/bicep/main.bicep' = {
  name: 'redpandaPlatform'
  params: {
    clusterName: clusterName
  }
}

// TODO: Add Redpanda-specific supporting resources and installation artifacts.

