targetScope = 'resourceGroup'

@description('AKS cluster name.')
param clusterName string = 'aks-apache-airflow-dev'

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

@description('Name of the dedicated Airflow user node pool.')
param airflowNodePoolName string = 'airflow'

@description('VM size for the dedicated Airflow user node pool.')
param airflowNodePoolVmSize string = 'Standard_D4s_v5'

@description('Node count for the dedicated Airflow user node pool.')
param airflowNodePoolCount int = 3

@description('OS disk size in GiB for the dedicated Airflow user node pool.')
param airflowNodePoolOsDiskSizeGb int = 128

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
    name: airflowNodePoolName
    availabilityZones: []
    count: airflowNodePoolCount
    vmSize: airflowNodePoolVmSize
    mode: 'User'
    osType: 'Linux'
    osDiskSizeGB: airflowNodePoolOsDiskSizeGb
    type: 'VirtualMachineScaleSets'
    nodeLabels: {
      workload: 'apache-airflow'
    }
    nodeTaints: [
      'dedicated=airflow:NoSchedule'
    ]
  }
]

module aksPlatform '../../../../../platform/aks-avm/bicep/main.bicep' = {
  name: 'apacheAirflowPlatform'
  params: {
    clusterName: clusterName
    location: location
    dnsPrefix: dnsPrefix
    primaryAgentPoolProfiles: primaryAgentPoolProfiles
    agentPools: agentPools
  }
}

output deployedClusterName string = clusterName
output deployedAirflowNodePool string = airflowNodePoolName
output deployedNamespace string = 'airflow'
