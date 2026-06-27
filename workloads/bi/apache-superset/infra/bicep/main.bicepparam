using './main.bicep'

param clusterName = 'aks-apache-superset-dev'
param location = 'swedencentral'
param systemNodePoolName = 'systempool'
param systemNodePoolVmSize = 'Standard_D2s_v6'
param systemNodePoolCount = 1
param supersetNodePoolName = 'superset'
param supersetNodePoolVmSize = 'Standard_D4s_v6'
param supersetNodePoolCount = 3
param supersetNodePoolOsDiskSizeGb = 128
