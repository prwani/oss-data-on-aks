targetScope = 'resourceGroup'

@description('AKS cluster name.')
param clusterName string

@description('Azure region for the AKS deployment.')
param location string = resourceGroup().location

@description('DNS prefix for the AKS API server.')
param dnsPrefix string = '${clusterName}-dns'

module managedCluster 'br/public:avm/res/container-service/managed-cluster:0.1.0' = {
  name: 'aksManagedCluster'
  params: {
    name: clusterName
    location: location
    dnsPrefix: dnsPrefix
    // Add the remaining required and optional parameters after pinning the
    // tested AVM module version for the blueprint.
  }
}

