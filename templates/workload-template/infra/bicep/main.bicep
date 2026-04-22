targetScope = 'resourceGroup'

@description('Short workload name used in labels and tags.')
param workloadName string = 'replace-me'

@description('Kubernetes namespace for the workload.')
param workloadNamespace string = 'replace-me'

@description('AKS cluster name.')
param clusterName string = 'aks-replace-me-dev'

@description('Azure region for supporting resources.')
param location string = resourceGroup().location

@description('VM size for the AKS system node pool.')
param systemPoolVmSize string = 'Standard_D2s_v5'

@description('Node count for the AKS system node pool.')
@minValue(1)
param systemPoolCount int = 1

@description('Short name for the dedicated workload node pool. AKS requires 1-12 lowercase alphanumeric characters.')
@minLength(1)
@maxLength(12)
param workloadPoolName string = 'workload'

@description('VM size for the dedicated workload node pool.')
param workloadPoolVmSize string = 'Standard_D4s_v5'

@description('Node count for the dedicated workload node pool.')
@minValue(1)
param workloadPoolCount int = 3

var primaryAgentPoolProfiles = [
  {
    name: 'systempool'
    availabilityZones: []
    count: systemPoolCount
    vmSize: systemPoolVmSize
    mode: 'System'
    osType: 'Linux'
    type: 'VirtualMachineScaleSets'
  }
]

var agentPools = [
  {
    name: workloadPoolName
    availabilityZones: []
    count: workloadPoolCount
    vmSize: workloadPoolVmSize
    mode: 'User'
    osType: 'Linux'
    type: 'VirtualMachineScaleSets'
    nodeTaints: [
      'dedicated=${workloadPoolName}:NoSchedule'
    ]
    nodeLabels: {
      workload: workloadName
      namespace: workloadNamespace
    }
  }
]

module aksPlatform '../../../../platform/aks-avm/bicep/main.bicep' = {
  name: 'workloadPlatform'
  params: {
    clusterName: clusterName
    location: location
    dnsPrefix: '${clusterName}-dns'
    primaryAgentPoolProfiles: primaryAgentPoolProfiles
    agentPools: agentPools
  }
}

output deployedClusterName string = clusterName
output deployedWorkloadPoolName string = workloadPoolName
output deployedWorkloadNamespace string = workloadNamespace
output getCredentialsCommand string = 'az aks get-credentials --resource-group ${resourceGroup().name} --name ${clusterName}'
