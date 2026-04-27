targetScope = 'resourceGroup'

@description('AKS cluster name.')
param clusterName string = 'aks-opensearch-dev'

@description('Azure region for supporting resources.')
param location string = resourceGroup().location

@description('Whether to create a starter storage account and container for OpenSearch snapshots.')
param deploySnapshotStorage bool = true

@description('Globally unique storage account name used for snapshot artifacts.')
param snapshotStorageAccountName string = 'opssnapdev001'

@description('Container name for OpenSearch snapshots.')
param snapshotContainerName string = 'opensearch-snapshots'

@description('Optional AKS API server access profile. Use this for private cluster settings or authorized IP ranges.')
param apiServerAccessProfile object?

@description('Optional public network access setting for AKS.')
param publicNetworkAccess string?

@description('Optional VNet subnet resource ID for AKS nodes.')
param vnetSubnetResourceId string = ''

@description('Optional managed identity configuration for the AKS cluster.')
param managedIdentities object = {
  systemAssigned: true
}

var snapshotServiceAccountNamespace = 'opensearch'
var snapshotManagerServiceAccountName = 'opensearch-manager-snapshots'
var snapshotDataServiceAccountName = 'opensearch-data-snapshots'
var snapshotManagerServiceAccountSubject = 'system:serviceaccount:${snapshotServiceAccountNamespace}:${snapshotManagerServiceAccountName}'
var snapshotDataServiceAccountSubject = 'system:serviceaccount:${snapshotServiceAccountNamespace}:${snapshotDataServiceAccountName}'
var snapshotManagedIdentityName = 'id-${clusterName}-snapshots'
var storageBlobDataContributorRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
)

var primaryAgentPoolProfiles = [
  {
    name: 'systempool'
    availabilityZones: []
    count: 1
    vmSize: 'Standard_D2s_v5'
    mode: 'System'
    osType: 'Linux'
    type: 'VirtualMachineScaleSets'
    vnetSubnetResourceId: empty(vnetSubnetResourceId) ? null : vnetSubnetResourceId
  }
]

var agentPools = [
  {
    name: 'osmgr'
    availabilityZones: []
    count: 3
    vmSize: 'Standard_D4s_v5'
    mode: 'User'
    osType: 'Linux'
    type: 'VirtualMachineScaleSets'
    nodeTaints: [
      'dedicated=opensearch-manager:NoSchedule'
    ]
    vnetSubnetResourceId: empty(vnetSubnetResourceId) ? null : vnetSubnetResourceId
  }
  {
    name: 'osdata'
    availabilityZones: []
    count: 3
    vmSize: 'Standard_D4s_v5'
    mode: 'User'
    osType: 'Linux'
    type: 'VirtualMachineScaleSets'
    nodeTaints: [
      'dedicated=opensearch-data:NoSchedule'
    ]
    vnetSubnetResourceId: empty(vnetSubnetResourceId) ? null : vnetSubnetResourceId
  }
]

module aksPlatform '../../../../../platform/aks-avm/bicep/main.bicep' = {
  name: 'opensearchPlatform'
  params: {
    clusterName: clusterName
    location: location
    dnsPrefix: '${clusterName}-dns'
    enableOidcIssuerProfile: true
    enableWorkloadIdentity: true
    managedIdentities: managedIdentities
    apiServerAccessProfile: apiServerAccessProfile
    publicNetworkAccess: publicNetworkAccess
    primaryAgentPoolProfiles: primaryAgentPoolProfiles
    agentPools: agentPools
  }
}

var clusterOidcIssuerUrl = aksPlatform.outputs.?clusterOidcIssuerUrl ?? ''

resource snapshotStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = if (deploySnapshotStorage) {
  name: snapshotStorageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  tags: {
    workload: 'opensearch'
    blueprint: 'opensearch-on-aks'
  }
  properties: {
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource snapshotBlobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = if (deploySnapshotStorage) {
  parent: snapshotStorage
  name: 'default'
}

resource snapshotContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = if (deploySnapshotStorage) {
  parent: snapshotBlobService
  name: snapshotContainerName
  properties: {
    publicAccess: 'None'
  }
}

resource snapshotManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = if (deploySnapshotStorage) {
  name: snapshotManagedIdentityName
  location: location
  tags: {
    workload: 'opensearch'
    blueprint: 'opensearch-on-aks'
  }
}

resource snapshotManagerFederatedCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = if (deploySnapshotStorage) {
  parent: snapshotManagedIdentity
  name: 'fic-${clusterName}-manager-snapshots'
  properties: {
    audiences: [
      'api://AzureADTokenExchange'
    ]
    issuer: clusterOidcIssuerUrl
    subject: snapshotManagerServiceAccountSubject
  }
}

resource snapshotDataFederatedCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = if (deploySnapshotStorage) {
  parent: snapshotManagedIdentity
  name: 'fic-${clusterName}-data-snapshots'
  properties: {
    audiences: [
      'api://AzureADTokenExchange'
    ]
    issuer: clusterOidcIssuerUrl
    subject: snapshotDataServiceAccountSubject
  }
  // Managed identity federated credential writes must be serialized.
  dependsOn: [
    snapshotManagerFederatedCredential
  ]
}

resource snapshotContainerBlobDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deploySnapshotStorage) {
  name: guid(snapshotContainer.id, snapshotManagedIdentity!.id, storageBlobDataContributorRoleDefinitionId)
  scope: snapshotContainer
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleDefinitionId
    principalId: snapshotManagedIdentity!.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output deployedClusterName string = aksPlatform.outputs.clusterName
output deployedClusterResourceId string = aksPlatform.outputs.clusterResourceId
output deployedClusterOidcIssuerUrl string? = aksPlatform.outputs.?clusterOidcIssuerUrl
output deployedClusterWorkloadIdentityEnabled bool = aksPlatform.outputs.clusterWorkloadIdentityEnabled
output deployedSnapshotStorageAccount string = deploySnapshotStorage ? snapshotStorageAccountName : ''
output deployedSnapshotStorageAccountId string = deploySnapshotStorage ? snapshotStorage.id : ''
output deployedSnapshotContainer string = deploySnapshotStorage ? snapshotContainerName : ''
output deployedSnapshotContainerId string = deploySnapshotStorage ? snapshotContainer.id : ''
output snapshotManagedIdentityClientId string = deploySnapshotStorage ? snapshotManagedIdentity!.properties.clientId : ''
output snapshotManagedIdentityPrincipalId string = deploySnapshotStorage ? snapshotManagedIdentity!.properties.principalId : ''
output snapshotManagedIdentityResourceId string = deploySnapshotStorage ? snapshotManagedIdentity!.id : ''
output snapshotManagerServiceAccountName string = snapshotManagerServiceAccountName
output snapshotManagerServiceAccountSubject string = snapshotManagerServiceAccountSubject
output snapshotDataServiceAccountName string = snapshotDataServiceAccountName
output snapshotDataServiceAccountSubject string = snapshotDataServiceAccountSubject
