targetScope = 'resourceGroup'

@description('AKS cluster name.')
param clusterName string = 'aks-redpanda-dev'

@description('Azure region for the AKS deployment.')
param location string = resourceGroup().location

@description('VM size for the system pool.')
param systemPoolVmSize string = 'Standard_D4ds_v5'

@description('Node count for the system pool.')
@minValue(1)
param systemPoolCount int = 1

@description('Availability zones for the system pool. Leave empty in regions without zone support.')
param systemPoolAvailabilityZones array = []

@description('VM size for the dedicated rpbroker pool. Choose an x86_64 family with SSE4.2 support.')
param brokerPoolVmSize string = 'Standard_D8ds_v5'

@description('Node count for the dedicated rpbroker pool. Keep this at 3 or higher so each broker can land on its own node.')
@minValue(3)
param brokerPoolCount int = 3

@description('Availability zones for the dedicated rpbroker pool. Use one zone per node when the region supports it.')
param brokerPoolAvailabilityZones array = []

var primaryAgentPoolProfiles = [
  {
    name: 'systempool'
    availabilityZones: systemPoolAvailabilityZones
    count: systemPoolCount
    vmSize: systemPoolVmSize
    mode: 'System'
    osType: 'Linux'
    type: 'VirtualMachineScaleSets'
  }
]

var agentPools = [
  {
    name: 'rpbroker'
    availabilityZones: brokerPoolAvailabilityZones
    count: brokerPoolCount
    vmSize: brokerPoolVmSize
    mode: 'User'
    osType: 'Linux'
    type: 'VirtualMachineScaleSets'
    nodeTaints: [
      'dedicated=redpanda-broker:NoSchedule'
    ]
  }
]

module aksPlatform '../../../../../platform/aks-avm/bicep/main.bicep' = {
  name: 'redpandaPlatform'
  params: {
    clusterName: clusterName
    location: location
    dnsPrefix: '${clusterName}-dns'
    primaryAgentPoolProfiles: primaryAgentPoolProfiles
    agentPools: agentPools
  }
}

output resourceGroupName string = resourceGroup().name
output deployedClusterName string = clusterName
output brokerNodePoolName string = 'rpbroker'
output getCredentialsCommand string = 'az aks get-credentials --resource-group ${resourceGroup().name} --name ${clusterName}'
