using './main.bicep'

param clusterName = 'aks-apache-superset-dev'
param location = 'eastus'
param systemNodePoolName = 'systempool'
param systemNodePoolVmSize = 'Standard_D2s_v5'
param systemNodePoolCount = 1
param supersetNodePoolName = 'superset'
param supersetNodePoolVmSize = 'Standard_D4s_v5'
param supersetNodePoolCount = 3
param supersetNodePoolOsDiskSizeGb = 128
