using './main.bicep'

param clusterName = 'aks-clickhouse-dev'
param location = 'eastus'
param systemPoolVmSize = 'Standard_D2s_v5'
param systemPoolNodeCount = 1
param clickhousePoolVmSize = 'Standard_E8ds_v5'
param clickhousePoolNodeCount = 3
