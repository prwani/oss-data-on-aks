using './main.bicep'

param clusterName = 'aks-trino-dev'
param location = 'eastus'
param systemPoolVmSize = 'Standard_D2s_v5'
param systemPoolNodeCount = 1
param trinoPoolVmSize = 'Standard_D8ds_v5'
param trinoPoolNodeCount = 3
