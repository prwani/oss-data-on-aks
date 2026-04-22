targetScope = 'resourceGroup'

@description('AKS cluster name.')
param clusterName string = 'aks-apache-kafka-dev'

@description('Azure region for supporting resources.')
param location string = resourceGroup().location

@description('VM size for the AKS system node pool.')
param systemPoolVmSize string = 'Standard_D2s_v5'

@description('Node count for the AKS system node pool.')
@minValue(1)
param systemPoolCount int = 1

@description('VM size for the dedicated kafka user pool.')
param kafkaPoolVmSize string = 'Standard_D4s_v5'

@description('Node count for the dedicated kafka user pool. Keep this at three or higher so the default Kafka hard anti-affinity rules can place all controllers and brokers.')
@minValue(3)
param kafkaPoolCount int = 3

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
    name: 'kafka'
    availabilityZones: []
    count: kafkaPoolCount
    vmSize: kafkaPoolVmSize
    mode: 'User'
    osType: 'Linux'
    type: 'VirtualMachineScaleSets'
    nodeTaints: [
      'dedicated=kafka:NoSchedule'
    ]
    nodeLabels: {
      workload: 'kafka'
    }
  }
]

module aksPlatform '../../../../../platform/aks-avm/bicep/main.bicep' = {
  name: 'apacheKafkaPlatform'
  params: {
    clusterName: clusterName
    location: location
    dnsPrefix: '${clusterName}-dns'
    primaryAgentPoolProfiles: primaryAgentPoolProfiles
    agentPools: agentPools
  }
}

output deployedClusterName string = clusterName
output deployedKafkaPoolName string = 'kafka'
output getCredentialsCommand string = 'az aks get-credentials --resource-group ${resourceGroup().name} --name ${clusterName}'
