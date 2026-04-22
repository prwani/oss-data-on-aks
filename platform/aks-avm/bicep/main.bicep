targetScope = 'resourceGroup'

@description('AKS cluster name.')
param clusterName string

@description('Azure region for the AKS deployment.')
param location string = resourceGroup().location

@description('DNS prefix for the AKS API server.')
param dnsPrefix string = '${clusterName}-dns'

@description('Primary system node pool profiles for the AKS cluster.')
param primaryAgentPoolProfiles array = [
  {
    name: 'systempool'
    availabilityZones: []
    count: 1
    vmSize: 'Standard_D2s_v5'
    mode: 'System'
    osType: 'Linux'
    type: 'VirtualMachineScaleSets'
  }
]

@description('Additional user node pools for workload placement.')
param agentPools array = []

@description('Managed identity configuration for the AKS cluster.')
param managedIdentities object = {
  systemAssigned: true
}

@description('Whether to disable local AKS accounts. Keep this false unless the cluster is AAD-integrated.')
param disableLocalAccounts bool = false

@description('Whether to enable the Azure Disk CSI driver.')
param enableStorageProfileDiskCSIDriver bool = true

@description('Whether to enable the Azure File CSI driver.')
param enableStorageProfileFileCSIDriver bool = true

@description('Whether to enable the CSI snapshot controller.')
param enableStorageProfileSnapshotController bool = true

module managedCluster 'br/public:avm/res/container-service/managed-cluster:0.13.0' = {
  name: 'aksManagedCluster'
  params: {
    name: clusterName
    location: location
    dnsPrefix: dnsPrefix
    primaryAgentPoolProfiles: primaryAgentPoolProfiles
    agentPools: agentPools
    managedIdentities: managedIdentities
    disableLocalAccounts: disableLocalAccounts
    enableStorageProfileDiskCSIDriver: enableStorageProfileDiskCSIDriver
    enableStorageProfileFileCSIDriver: enableStorageProfileFileCSIDriver
    enableStorageProfileSnapshotController: enableStorageProfileSnapshotController
  }
}
