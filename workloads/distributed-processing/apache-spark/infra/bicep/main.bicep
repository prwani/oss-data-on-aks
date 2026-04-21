targetScope = 'resourceGroup'

param clusterName string = 'aks-apache-spark-dev'

module aksPlatform '../../../../../platform/aks-avm/bicep/main.bicep' = {
  name: 'apacheSparkPlatform'
  params: {
    clusterName: clusterName
  }
}

// TODO: Add Spark-specific supporting resources and installation artifacts.

