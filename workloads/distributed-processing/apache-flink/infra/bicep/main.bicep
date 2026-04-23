targetScope = 'resourceGroup'

@description('AKS cluster name.')
param clusterName string = 'aks-apache-flink-dev'

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

@description('Name of the dedicated Flink user node pool.')
param flinkNodePoolName string = 'flink'

@description('VM size for the dedicated Flink user node pool.')
param flinkNodePoolVmSize string = 'Standard_D8ds_v5'

@description('Node count for the dedicated Flink user node pool.')
param flinkNodePoolCount int = 3

@description('OS disk size in GiB for the dedicated Flink user node pool.')
param flinkNodePoolOsDiskSizeGb int = 128

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
    name: flinkNodePoolName
    availabilityZones: []
    count: flinkNodePoolCount
    vmSize: flinkNodePoolVmSize
    mode: 'User'
    osType: 'Linux'
    osDiskSizeGB: flinkNodePoolOsDiskSizeGb
    type: 'VirtualMachineScaleSets'
    nodeLabels: {
      workload: 'apache-flink'
    }
    nodeTaints: [
      'dedicated=flink:NoSchedule'
    ]
  }
]

module aksPlatform '../../../../../platform/aks-avm/bicep/main.bicep' = {
  name: 'apacheFlinkPlatform'
  params: {
    clusterName: clusterName
    location: location
    dnsPrefix: dnsPrefix
    primaryAgentPoolProfiles: primaryAgentPoolProfiles
    agentPools: agentPools
  }
}

output deployedClusterName string = clusterName
output deployedFlinkNodePool string = flinkNodePoolName
output deployedFlinkNamespace string = 'flink'
output deployedFlinkOperatorNamespace string = 'flink-operator'
