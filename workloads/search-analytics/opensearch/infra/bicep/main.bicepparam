using './main.bicep'

param clusterName = 'aks-opensearch-dev'
param location = 'eastus'
param deploySnapshotStorage = true
param snapshotStorageAccountName = 'opssnapdev001'
param snapshotContainerName = 'opensearch-snapshots'
