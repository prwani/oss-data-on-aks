targetScope = 'resourceGroup'

param clusterName string = 'aks-opensearch-dev'

module aksPlatform '../../../../../platform/aks-avm/bicep/main.bicep' = {
  name: 'opensearchPlatform'
  params: {
    clusterName: clusterName
  }
}

// TODO: Extend this workload with OpenSearch-specific Azure and Kubernetes assets.

