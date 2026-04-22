targetScope = 'resourceGroup'

@description('AKS cluster name.')
param clusterName string = 'aks-apache-spark-dev'

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

@description('Name of the dedicated Spark user node pool.')
param sparkNodePoolName string = 'spark'

@description('VM size for the dedicated Spark user node pool.')
param sparkNodePoolVmSize string = 'Standard_D8ds_v5'

@description('Node count for the dedicated Spark user node pool.')
param sparkNodePoolCount int = 3

@description('OS disk size in GiB for the dedicated Spark user node pool.')
param sparkNodePoolOsDiskSizeGb int = 128

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
    name: sparkNodePoolName
    availabilityZones: []
    count: sparkNodePoolCount
    vmSize: sparkNodePoolVmSize
    mode: 'User'
    osType: 'Linux'
    osDiskSizeGB: sparkNodePoolOsDiskSizeGb
    type: 'VirtualMachineScaleSets'
    nodeLabels: {
      workload: 'apache-spark'
    }
    nodeTaints: [
      'dedicated=spark:NoSchedule'
    ]
  }
]

module aksPlatform '../../../../../platform/aks-avm/bicep/main.bicep' = {
  name: 'apacheSparkPlatform'
  params: {
    clusterName: clusterName
    location: location
    dnsPrefix: dnsPrefix
    primaryAgentPoolProfiles: primaryAgentPoolProfiles
    agentPools: agentPools
  }
}

output deployedClusterName string = clusterName
output deployedSparkNodePool string = sparkNodePoolName
output deployedSparkNamespace string = 'spark'
output deployedSparkOperatorNamespace string = 'spark-operator'
