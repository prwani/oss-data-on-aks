targetScope = 'resourceGroup'

@description('AKS cluster name.')
param clusterName string = 'aks-trino-dev'

@description('Azure region for the AKS deployment.')
param location string = resourceGroup().location

@description('ADLS Gen2 storage account name. Leave empty to generate a deterministic name.')
param lakehouseStorageAccountName string = ''

@description('ADLS Gen2 file system/container for Iceberg table data.')
param lakehouseFileSystemName string = 'lakehouse'

@description('User-assigned managed identity name used by Trino and the Iceberg REST catalog for ADLS Gen2 access.')
param lakehouseIdentityName string = '${clusterName}-lakehouse-uami'

@description('PostgreSQL Flexible Server name for Apache Polaris metadata. Leave empty to generate a deterministic name.')
param polarisPostgreSqlServerName string = ''

@description('PostgreSQL database name for Apache Polaris metadata.')
param polarisPostgreSqlDatabaseName string = 'polaris'

@description('PostgreSQL administrator login for Apache Polaris metadata.')
param polarisPostgreSqlAdminLogin string = 'polarisadmin'

@secure()
@description('PostgreSQL administrator password for Apache Polaris metadata. Pass this at deployment time; do not commit it.')
param polarisPostgreSqlAdminPassword string = ''

@description('PostgreSQL Flexible Server SKU for Apache Polaris metadata.')
param polarisPostgreSqlSkuName string = 'Standard_B1ms'

@description('PostgreSQL Flexible Server storage size in GiB.')
@minValue(32)
param polarisPostgreSqlStorageSizeGiB int = 32

@description('VM size for the system node pool.')
param systemPoolVmSize string = 'Standard_D2s_v6'

@description('Node count for the system node pool.')
@minValue(1)
param systemPoolNodeCount int = 1

@description('VM size for the dedicated Trino user pool.')
param trinoPoolVmSize string = 'Standard_L8s_v3'

@description('Node count for the dedicated Trino user pool.')
@minValue(1)
param trinoPoolNodeCount int = 3

@description('VM size for the Iceberg REST catalog user pool.')
param catalogPoolVmSize string = 'Standard_D4s_v6'

@description('Node count for the Iceberg REST catalog user pool.')
@minValue(1)
param catalogPoolNodeCount int = 2

var generatedStorageAccountName = toLower('st${uniqueString(resourceGroup().id, clusterName, 'lakehouse')}')
var resolvedStorageAccountName = empty(lakehouseStorageAccountName) ? generatedStorageAccountName : lakehouseStorageAccountName
var generatedPostgreSqlServerName = toLower('psql-${uniqueString(resourceGroup().id, clusterName, 'polaris')}')
var resolvedPostgreSqlServerName = empty(polarisPostgreSqlServerName) ? generatedPostgreSqlServerName : polarisPostgreSqlServerName
var storageBlobDataContributorRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')

resource lakehouseIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: lakehouseIdentityName
  location: location
}

resource lakehouseStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: resolvedStorageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    isHnsEnabled: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: lakehouseStorage
  name: 'default'
}

resource lakehouseFileSystem 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: lakehouseFileSystemName
  properties: {
    publicAccess: 'None'
  }
}

resource lakehouseStorageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(lakehouseStorage.id, lakehouseIdentity.id, storageBlobDataContributorRoleDefinitionId)
  scope: lakehouseStorage
  properties: {
    principalId: lakehouseIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: storageBlobDataContributorRoleDefinitionId
  }
}

resource polarisPostgreSqlServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-12-01-preview' = {
  name: resolvedPostgreSqlServerName
  location: location
  sku: {
    name: polarisPostgreSqlSkuName
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: polarisPostgreSqlAdminLogin
    administratorLoginPassword: polarisPostgreSqlAdminPassword
    authConfig: {
      activeDirectoryAuth: 'Disabled'
      passwordAuth: 'Enabled'
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    createMode: 'Default'
    highAvailability: {
      mode: 'Disabled'
    }
    network: {
      publicNetworkAccess: 'Enabled'
    }
    storage: {
      storageSizeGB: polarisPostgreSqlStorageSizeGiB
    }
    version: '16'
  }
}

resource polarisPostgreSqlDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-12-01-preview' = {
  parent: polarisPostgreSqlServer
  name: polarisPostgreSqlDatabaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

resource polarisPostgreSqlAllowAzureServices 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-12-01-preview' = {
  parent: polarisPostgreSqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

var primaryAgentPoolProfiles = [
  {
    name: 'systempool'
    availabilityZones: []
    count: systemPoolNodeCount
    vmSize: systemPoolVmSize
    mode: 'System'
    osType: 'Linux'
    type: 'VirtualMachineScaleSets'
  }
]

var agentPools = [
  {
    name: 'trino'
    availabilityZones: []
    count: trinoPoolNodeCount
    vmSize: trinoPoolVmSize
    mode: 'User'
    osType: 'Linux'
    type: 'VirtualMachineScaleSets'
    nodeTaints: [
      'dedicated=trino:NoSchedule'
    ]
  }
  {
    name: 'catalog'
    availabilityZones: []
    count: catalogPoolNodeCount
    vmSize: catalogPoolVmSize
    mode: 'User'
    osType: 'Linux'
    type: 'VirtualMachineScaleSets'
    nodeTaints: [
      'dedicated=catalog:NoSchedule'
    ]
  }
]

module aksPlatform '../../../../../platform/aks-avm/bicep/main.bicep' = {
  name: 'trinoPlatform'
  params: {
    clusterName: clusterName
    location: location
    dnsPrefix: '${clusterName}-dns'
    primaryAgentPoolProfiles: primaryAgentPoolProfiles
    agentPools: agentPools
    enableOidcIssuerProfile: true
    enableWorkloadIdentity: true
  }
  dependsOn: [
    lakehouseStorageRoleAssignment
    polarisPostgreSqlDatabase
    polarisPostgreSqlAllowAzureServices
  ]
}

resource trinoServiceAccountFederatedCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: lakehouseIdentity
  name: 'trino-service-account'
  properties: {
    audiences: [
      'api://AzureADTokenExchange'
    ]
    issuer: aksPlatform.outputs.clusterOidcIssuerUrl!
    subject: 'system:serviceaccount:trino:trino'
  }
}

resource catalogServiceAccountFederatedCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: lakehouseIdentity
  name: 'iceberg-rest-catalog-service-account'
  properties: {
    audiences: [
      'api://AzureADTokenExchange'
    ]
    issuer: aksPlatform.outputs.clusterOidcIssuerUrl!
    subject: 'system:serviceaccount:iceberg-catalog:polaris'
  }
  dependsOn: [
    trinoServiceAccountFederatedCredential
  ]
}

output resourceGroupName string = resourceGroup().name
output deployedClusterName string = clusterName
output dedicatedNodePoolName string = 'trino'
output catalogNodePoolName string = 'catalog'
output namespaceName string = 'trino'
output getCredentialsCommand string = 'az aks get-credentials --resource-group ${resourceGroup().name} --name ${clusterName}'
output lakehouseStorageAccountName string = lakehouseStorage.name
output lakehouseFileSystemName string = lakehouseFileSystem.name
output lakehouseWarehouseUri string = 'abfss://${lakehouseFileSystem.name}@${lakehouseStorage.name}.dfs.${environment().suffixes.storage}/iceberg/warehouse'
output lakehouseIdentityClientId string = lakehouseIdentity.properties.clientId
output lakehouseIdentityResourceId string = lakehouseIdentity.id
output polarisPostgreSqlServerName string = polarisPostgreSqlServer.name
output polarisPostgreSqlDatabaseName string = polarisPostgreSqlDatabase.name
output polarisPostgreSqlHost string = polarisPostgreSqlServer.properties.fullyQualifiedDomainName
output polarisPostgreSqlJdbcUrl string = 'jdbc:postgresql://${polarisPostgreSqlServer.properties.fullyQualifiedDomainName}:5432/${polarisPostgreSqlDatabase.name}?sslmode=require'
output polarisPostgreSqlAdminLogin string = polarisPostgreSqlAdminLogin
