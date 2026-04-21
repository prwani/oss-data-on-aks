targetScope = 'resourceGroup'

@description('AKS cluster name.')
param clusterName string = 'aks-opensearch-dev'

@description('Azure region for supporting resources.')
param location string = resourceGroup().location

@description('Whether to create a starter storage account and container for OpenSearch snapshots.')
param deploySnapshotStorage bool = true

@description('Globally unique storage account name used for snapshot artifacts.')
param snapshotStorageAccountName string = 'opssnapdev001'

@description('Container name for OpenSearch snapshots.')
param snapshotContainerName string = 'opensearch-snapshots'

module aksPlatform '../../../../../platform/aks-avm/bicep/main.bicep' = {
  name: 'opensearchPlatform'
  params: {
    clusterName: clusterName
    location: location
    dnsPrefix: '${clusterName}-dns'
  }
}

resource snapshotStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = if (deploySnapshotStorage) {
  name: snapshotStorageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  tags: {
    workload: 'opensearch'
    blueprint: 'opensearch-on-aks'
  }
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource snapshotBlobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = if (deploySnapshotStorage) {
  parent: snapshotStorage
  name: 'default'
}

resource snapshotContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = if (deploySnapshotStorage) {
  parent: snapshotBlobService
  name: snapshotContainerName
  properties: {
    publicAccess: 'None'
  }
}

output deployedClusterName string = clusterName
output deployedSnapshotStorageAccount string = deploySnapshotStorage ? snapshotStorageAccountName : ''
output deployedSnapshotContainer string = deploySnapshotStorage ? snapshotContainerName : ''
