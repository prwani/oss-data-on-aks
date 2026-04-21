targetScope = 'resourceGroup'

param clusterName string = 'aks-apache-kafka-dev'

module aksPlatform '../../../../../platform/aks-avm/bicep/main.bicep' = {
  name: 'apacheKafkaPlatform'
  params: {
    clusterName: clusterName
  }
}

// TODO: Add Kafka-specific supporting resources and installation artifacts.

