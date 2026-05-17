using './main.bicep'

param clusterName = 'aks-opensearch-dev'
param location = 'eastus'
param deploySnapshotStorage = true
param snapshotContainerName = 'opensearch-snapshots'
