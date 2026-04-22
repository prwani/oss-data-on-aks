using './main.bicep'

param clusterName = 'aks-apache-airflow-dev'
param location = 'eastus'
param systemNodePoolName = 'systempool'
param systemNodePoolVmSize = 'Standard_D2s_v5'
param systemNodePoolCount = 1
param airflowNodePoolName = 'airflow'
param airflowNodePoolVmSize = 'Standard_D4s_v5'
param airflowNodePoolCount = 3
param airflowNodePoolOsDiskSizeGb = 128
