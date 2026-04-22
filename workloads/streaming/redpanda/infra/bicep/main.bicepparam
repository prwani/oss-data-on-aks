using './main.bicep'

param clusterName = 'aks-redpanda-dev'
param location = 'eastus'
param systemPoolVmSize = 'Standard_D4ds_v5'
param systemPoolCount = 1
param systemPoolAvailabilityZones = []
param brokerPoolVmSize = 'Standard_D8ds_v5'
param brokerPoolCount = 3
param brokerPoolAvailabilityZones = []
