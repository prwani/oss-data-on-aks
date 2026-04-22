using './main.bicep'

param clusterName = 'aks-apache-spark-dev'
param location = 'eastus'
param systemNodePoolName = 'systempool'
param systemNodePoolVmSize = 'Standard_D2s_v5'
param systemNodePoolCount = 1
param sparkNodePoolName = 'spark'
param sparkNodePoolVmSize = 'Standard_D8ds_v5'
param sparkNodePoolCount = 3
param sparkNodePoolOsDiskSizeGb = 128
