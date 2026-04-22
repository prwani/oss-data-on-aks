using './main.bicep'

param clusterName = 'aks-apache-kafka-dev'
param location = 'eastus'
param systemPoolVmSize = 'Standard_D2s_v5'
param systemPoolCount = 1
param kafkaPoolVmSize = 'Standard_D4s_v5'
param kafkaPoolCount = 3
