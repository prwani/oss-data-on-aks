using './main.bicep'

param clusterName = 'aks-apache-flink-dev'
param location = 'eastus'
param systemNodePoolName = 'systempool'
param systemNodePoolVmSize = 'Standard_D2s_v5'
param systemNodePoolCount = 1
param flinkNodePoolName = 'flink'
param flinkNodePoolVmSize = 'Standard_D8ds_v5'
param flinkNodePoolCount = 3
param flinkNodePoolOsDiskSizeGb = 128
