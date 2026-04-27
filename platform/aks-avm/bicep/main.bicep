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

@description('Whether to enable the AKS OIDC issuer profile.')
param enableOidcIssuerProfile bool = false

@description('Whether to enable AKS workload identity support.')
param enableWorkloadIdentity bool = false

@description('Whether to disable local AKS accounts. Keep this false unless the cluster is AAD-integrated.')
param disableLocalAccounts bool = false

@description('Optional AKS API server access profile. Use this for private cluster settings or authorized IP ranges.')
param apiServerAccessProfile object?

@description('Optional public network access setting for AKS.')
param publicNetworkAccess string?

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
    enableOidcIssuerProfile: enableOidcIssuerProfile
    securityProfile: enableWorkloadIdentity
      ? {
          workloadIdentity: {
            enabled: true
          }
        }
      : null
    disableLocalAccounts: disableLocalAccounts
    enableStorageProfileDiskCSIDriver: enableStorageProfileDiskCSIDriver
    enableStorageProfileFileCSIDriver: enableStorageProfileFileCSIDriver
    enableStorageProfileSnapshotController: enableStorageProfileSnapshotController
    apiServerAccessProfile: apiServerAccessProfile
    publicNetworkAccess: publicNetworkAccess
  }
}

output resourceGroupName string = resourceGroup().name
output location string = location
output clusterName string = managedCluster.outputs.name
output clusterResourceId string = managedCluster.outputs.resourceId
output clusterOidcIssuerEnabled bool = enableOidcIssuerProfile
output clusterOidcIssuerUrl string? = managedCluster.outputs.?oidcIssuerUrl
output clusterWorkloadIdentityEnabled bool = enableWorkloadIdentity
output clusterIdentityTenantId string = subscription().tenantId
output clusterSystemAssignedIdentityPrincipalId string? = managedCluster.outputs.?systemAssignedMIPrincipalId
output clusterUserAssignedIdentityResourceIds array = managedIdentities.?userAssignedResourceIds ?? []
output kubeletIdentityClientId string? = managedCluster.outputs.?kubeletIdentityClientId
output kubeletIdentityObjectId string? = managedCluster.outputs.?kubeletIdentityObjectId
output kubeletIdentityResourceId string? = managedCluster.outputs.?kubeletIdentityResourceId
