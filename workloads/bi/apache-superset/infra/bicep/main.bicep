targetScope = 'resourceGroup'

@description('AKS cluster name.')
param clusterName string = 'aks-apache-superset-dev'

@description('Azure region for supporting resources.')
param location string = resourceGroup().location

@description('DNS prefix for the AKS API server.')
param dnsPrefix string = '${clusterName}-dns'

@description('Name of the AKS system node pool.')
param systemNodePoolName string = 'systempool'

@description('VM size for the AKS system node pool.')
param systemNodePoolVmSize string = 'Standard_D2s_v5'

@description('Node count for the AKS system node pool.')
param systemNodePoolCount int = 1

@description('Name of the dedicated Superset user node pool.')
param supersetNodePoolName string = 'superset'

@description('VM size for the dedicated Superset user node pool.')
param supersetNodePoolVmSize string = 'Standard_D4s_v5'

@description('Node count for the dedicated Superset user node pool.')
param supersetNodePoolCount int = 3

@description('OS disk size in GiB for the dedicated Superset user node pool.')
param supersetNodePoolOsDiskSizeGb int = 128

var primaryAgentPoolProfiles = [
  {
    name: systemNodePoolName
    availabilityZones: []
    count: systemNodePoolCount
    vmSize: systemNodePoolVmSize
    mode: 'System'
    osType: 'Linux'
    type: 'VirtualMachineScaleSets'
  }
]

var agentPools = [
  {
    name: supersetNodePoolName
    availabilityZones: []
    count: supersetNodePoolCount
    vmSize: supersetNodePoolVmSize
    mode: 'User'
    osType: 'Linux'
    osDiskSizeGB: supersetNodePoolOsDiskSizeGb
    type: 'VirtualMachineScaleSets'
    nodeLabels: {
      workload: 'apache-superset'
    }
    nodeTaints: [
      'dedicated=superset:NoSchedule'
    ]
  }
]

module aksPlatform '../../../../../platform/aks-avm/bicep/main.bicep' = {
  name: 'apacheSupersetPlatform'
  params: {
    clusterName: clusterName
    location: location
    dnsPrefix: dnsPrefix
    primaryAgentPoolProfiles: primaryAgentPoolProfiles
    agentPools: agentPools
  }
}

output deployedClusterName string = clusterName
output deployedSupersetNodePool string = supersetNodePoolName
output deployedNamespace string = 'superset'
