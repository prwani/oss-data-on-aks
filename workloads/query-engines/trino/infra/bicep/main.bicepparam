using './main.bicep'

param clusterName = 'aks-trino-dev'
param location = 'swedencentral'
param lakehouseFileSystemName = 'lakehouse'
param polarisPostgreSqlDatabaseName = 'polaris'
param polarisPostgreSqlAdminLogin = 'polarisadmin'
param polarisPostgreSqlSkuName = 'Standard_B1ms'
param polarisPostgreSqlStorageSizeGiB = 32
param systemPoolVmSize = 'Standard_D2s_v6'
param systemPoolNodeCount = 1
param trinoPoolVmSize = 'Standard_L8s_v3'
param trinoPoolNodeCount = 3
param catalogPoolVmSize = 'Standard_D4s_v6'
param catalogPoolNodeCount = 2
