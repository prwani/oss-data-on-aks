targetScope = 'resourceGroup'

param clusterName string = 'aks-replace-me-dev'

module aksPlatform '../../../../platform/aks-avm/bicep/main.bicep' = {
  name: 'replaceMePlatform'
  params: {
    clusterName: clusterName
  }
}

