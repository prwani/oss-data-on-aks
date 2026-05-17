targetScope = 'resourceGroup'

@description('AKS cluster name.')
param clusterName string = 'aks-opensearch-secure-dev'

@description('Azure region for supporting resources.')
param location string = resourceGroup().location

@description('Optional tags to apply to Azure resources created by this template.')
param tags object = {}

@description('Globally unique storage account name used for snapshot artifacts. Defaults to a deterministic name with a subscription, resource group, and cluster-specific suffix.')
param snapshotStorageAccountName string = take('opssnap${uniqueString(subscription().subscriptionId, resourceGroup().name, clusterName)}', 24)

@description('Container name for OpenSearch snapshots.')
param snapshotContainerName string = 'opensearch-snapshots'

@description('Virtual network address prefix for the private AKS deployment.')
param virtualNetworkAddressPrefix string = '10.240.0.0/16'

@description('AKS node subnet address prefix.')
param aksSubnetAddressPrefix string = '10.240.0.0/20'

@description('Azure Bastion subnet address prefix. AzureBastionSubnet must be /26 or larger.')
param bastionSubnetAddressPrefix string = '10.240.16.0/26'

@description('Whether to deploy Azure Bastion for native AKS private cluster access.')
param deployBastion bool = true

@allowed([
  'Standard'
  'Premium'
])
@description('Azure Bastion SKU. Native client tunneling for AKS private cluster access requires Standard or Premium.')
param bastionSku string = 'Standard'

var virtualNetworkName = 'vnet-${clusterName}'
var aksSubnetName = 'snet-aks'
var bastionSubnetName = 'AzureBastionSubnet'
var bastionName = 'bas-${clusterName}'
var bastionPublicIpName = 'pip-${clusterName}-bastion'
var clusterIdentityName = 'id-${clusterName}-aks'
var secureResourceTags = union(tags, {
  workload: 'opensearch'
  blueprint: 'opensearch-on-aks'
  securityProfile: 'secure'
})
var bastionResourceTags = union(secureResourceTags, {
  purpose: 'private-aks-access'
})
var networkContributorRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '4d97b98b-1d4f-4787-a291-c67834d212e7'
)

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: virtualNetworkName
  location: location
  tags: secureResourceTags
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkAddressPrefix
      ]
    }
    subnets: concat(
      [
        {
          name: aksSubnetName
          properties: {
            addressPrefix: aksSubnetAddressPrefix
          }
        }
      ],
      deployBastion
        ? [
            {
              name: bastionSubnetName
              properties: {
                addressPrefix: bastionSubnetAddressPrefix
              }
            }
          ]
        : []
    )
  }
}

resource aksSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: virtualNetwork
  name: aksSubnetName
}

resource bastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = if (deployBastion) {
  parent: virtualNetwork
  name: bastionSubnetName
}

resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = if (deployBastion) {
  name: bastionPublicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  tags: bastionResourceTags
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2024-05-01' = if (deployBastion) {
  name: bastionName
  location: location
  sku: {
    name: bastionSku
  }
  tags: bastionResourceTags
  properties: {
    enableTunneling: true
    ipConfigurations: [
      {
        name: 'bastion-ipconfig'
        properties: {
          subnet: {
            id: bastionSubnet.id
          }
          publicIPAddress: {
            id: bastionPublicIp.id
          }
        }
      }
    ]
  }
}

resource clusterIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: clusterIdentityName
  location: location
  tags: secureResourceTags
}

resource clusterIdentityNetworkContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aksSubnet.id, clusterIdentity.id, networkContributorRoleDefinitionId)
  scope: aksSubnet
  properties: {
    roleDefinitionId: networkContributorRoleDefinitionId
    principalId: clusterIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

module opensearchBaseline '../bicep/main.bicep' = {
  name: 'opensearchSecureBaseline'
  params: {
    clusterName: clusterName
    location: location
    tags: tags
    deploySnapshotStorage: true
    snapshotStorageAccountName: snapshotStorageAccountName
    snapshotContainerName: snapshotContainerName
    managedIdentities: {
      userAssignedResourceIds: [
        clusterIdentity.id
      ]
    }
    vnetSubnetResourceId: aksSubnet.id
    apiServerAccessProfile: {
      enablePrivateCluster: true
      enablePrivateClusterPublicFQDN: false
      privateDNSZone: 'System'
    }
    publicNetworkAccess: 'Disabled'
  }
  dependsOn: [
    clusterIdentityNetworkContributor
  ]
}

output deployedClusterName string = opensearchBaseline.outputs.deployedClusterName
output deployedSnapshotStorageAccount string = opensearchBaseline.outputs.deployedSnapshotStorageAccount
output snapshotManagedIdentityClientId string = opensearchBaseline.outputs.snapshotManagedIdentityClientId
output virtualNetworkResourceId string = virtualNetwork.id
output aksSubnetResourceId string = aksSubnet.id
output bastionResourceId string = deployBastion ? bastionHost.id : ''
output getCredentialsCommand string = 'az aks get-credentials --admin --resource-group ${resourceGroup().name} --name ${clusterName}'
output aksBastionCommand string = deployBastion ? 'az aks bastion --admin --resource-group ${resourceGroup().name} --name ${clusterName} --bastion ${bastionHost.id}' : 'Provide a Standard or Premium Azure Bastion resource ID, then run: az aks bastion --admin --resource-group ${resourceGroup().name} --name ${clusterName} --bastion <bastion-resource-id>'
output operatorBootstrapNote string = 'Open an AKS private-cluster tunnel with Azure Bastion, then run the Kubernetes, Helm, snapshot repository, and store-search sample steps from the Blog 2 guidance.'
