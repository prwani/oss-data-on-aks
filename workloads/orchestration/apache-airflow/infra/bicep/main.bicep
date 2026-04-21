targetScope = 'resourceGroup'

param clusterName string = 'aks-apache-airflow-dev'

module aksPlatform '../../../../../platform/aks-avm/bicep/main.bicep' = {
  name: 'apacheAirflowPlatform'
  params: {
    clusterName: clusterName
  }
}

// TODO: Add Airflow-specific supporting resources and installation artifacts.

