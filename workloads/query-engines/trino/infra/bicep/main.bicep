targetScope = 'resourceGroup'

@description('AKS cluster name.')
param clusterName string = 'aks-trino-dev'

@description('Azure region for the AKS deployment.')
param location string = resourceGroup().location

@description('VM size for the system node pool.')
param systemPoolVmSize string = 'Standard_D2s_v5'

@description('Node count for the system node pool.')
@minValue(1)
param systemPoolNodeCount int = 1

@description('VM size for the dedicated Trino user pool.')
param trinoPoolVmSize string = 'Standard_D8ds_v5'

@description('Node count for the dedicated Trino user pool.')
@minValue(1)
param trinoPoolNodeCount int = 3

var primaryAgentPoolProfiles = [
  {
    name: 'systempool'
    availabilityZones: []
    count: systemPoolNodeCount
    vmSize: systemPoolVmSize
    mode: 'System'
    osType: 'Linux'
    type: 'VirtualMachineScaleSets'
  }
]

var agentPools = [
  {
    name: 'trino'
    availabilityZones: []
    count: trinoPoolNodeCount
    vmSize: trinoPoolVmSize
    mode: 'User'
    osType: 'Linux'
    type: 'VirtualMachineScaleSets'
    nodeTaints: [
      'dedicated=trino:NoSchedule'
    ]
  }
]

module aksPlatform '../../../../../platform/aks-avm/bicep/main.bicep' = {
  name: 'trinoPlatform'
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
output dedicatedNodePoolName string = 'trino'
output namespaceName string = 'trino'
output getCredentialsCommand string = 'az aks get-credentials --resource-group ${resourceGroup().name} --name ${clusterName}'
