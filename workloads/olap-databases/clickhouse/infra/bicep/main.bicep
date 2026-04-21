targetScope = 'resourceGroup'

param clusterName string = 'aks-clickhouse-dev'

module aksPlatform '../../../../../platform/aks-avm/bicep/main.bicep' = {
  name: 'clickhousePlatform'
  params: {
    clusterName: clusterName
  }
}

// TODO: Add ClickHouse-specific supporting resources and installation artifacts.

