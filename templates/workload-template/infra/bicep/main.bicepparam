using './main.bicep'

param workloadName = 'replace-me'
param workloadNamespace = 'replace-me'
param clusterName = 'aks-replace-me-dev'
param location = 'eastus'
param systemPoolVmSize = 'Standard_D2s_v5'
param systemPoolCount = 1
param workloadPoolName = 'workload'
param workloadPoolVmSize = 'Standard_D4s_v5'
param workloadPoolCount = 3
