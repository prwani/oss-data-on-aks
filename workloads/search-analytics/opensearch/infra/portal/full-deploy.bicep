targetScope = 'resourceGroup'

@description('AKS cluster name.')
param clusterName string = 'aks-opensearch-dev'

@description('Azure region for supporting resources.')
param location string = resourceGroup().location

@description('Globally unique storage account name used for snapshot artifacts.')
param snapshotStorageAccountName string = 'opssnapdev001'

@description('Container name for OpenSearch snapshots.')
param snapshotContainerName string = 'opensearch-snapshots'

@secure()
@minLength(8)
@description('Initial OpenSearch admin password. This is stored only as Kubernetes secrets during the deployment script step.')
param adminPassword string

@description('Raw GitHub content base URL used by the deployment script to fetch Kubernetes manifests and Helm values.')
param rawContentBaseUrl string = 'https://raw.githubusercontent.com/prwani/oss-data-on-aks/main'

@description('OpenSearch Helm chart version for manager and data nodes.')
param opensearchHelmVersion string = '3.6.0'

@description('OpenSearch Dashboards Helm chart version.')
param opensearchDashboardsHelmVersion string = '3.2.0'

@description('Deployment script force-update tag. Keep the default unless you intentionally need to rerun the script during an incremental redeployment.')
param deploymentScriptForceUpdateTag string = utcNow()

var deploymentScriptIdentityName = 'id-${clusterName}-portal-deploy'
var aksClusterAdminRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '0ab0b1a8-8aac-4efd-b8c2-3ee1fb270be8'
)

module opensearchBaseline '../bicep/main.bicep' = {
  name: 'opensearchBaseline'
  params: {
    clusterName: clusterName
    location: location
    deploySnapshotStorage: true
    snapshotStorageAccountName: snapshotStorageAccountName
    snapshotContainerName: snapshotContainerName
  }
}

resource aksCluster 'Microsoft.ContainerService/managedClusters@2025-10-01' existing = {
  name: clusterName
}

resource deploymentScriptIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: deploymentScriptIdentityName
  location: location
  tags: {
    workload: 'opensearch'
    blueprint: 'opensearch-on-aks'
    purpose: 'portal-full-deployment'
  }
}

resource deploymentScriptAksAdminRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aksCluster.id, deploymentScriptIdentity.id, aksClusterAdminRoleDefinitionId)
  scope: aksCluster
  properties: {
    roleDefinitionId: aksClusterAdminRoleDefinitionId
    principalId: deploymentScriptIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    opensearchBaseline
  ]
}

resource installOpenSearch 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'install-opensearch-${uniqueString(resourceGroup().id, clusterName)}'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deploymentScriptIdentity.id}': {}
    }
  }
  properties: {
    azCliVersion: '2.63.0'
    timeout: 'PT1H'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: deploymentScriptForceUpdateTag
    environmentVariables: [
      {
        name: 'RESOURCE_GROUP'
        value: resourceGroup().name
      }
      {
        name: 'CLUSTER_NAME'
        value: clusterName
      }
      {
        name: 'SNAPSHOT_STORAGE_ACCOUNT'
        value: snapshotStorageAccountName
      }
      {
        name: 'SNAPSHOT_CONTAINER'
        value: snapshotContainerName
      }
      {
        name: 'SNAPSHOT_IDENTITY_CLIENT_ID'
        value: opensearchBaseline.outputs.snapshotManagedIdentityClientId
      }
      {
        name: 'RAW_CONTENT_BASE_URL'
        value: rawContentBaseUrl
      }
      {
        name: 'OPENSEARCH_HELM_VERSION'
        value: opensearchHelmVersion
      }
      {
        name: 'OPENSEARCH_DASHBOARDS_HELM_VERSION'
        value: opensearchDashboardsHelmVersion
      }
      {
        name: 'ADMIN_PASSWORD'
        secureValue: adminPassword
      }
    ]
    scriptContent: '''
      #!/usr/bin/env bash
      set -euo pipefail

      export PATH="/usr/local/bin:${PATH}"
      workdir="$(mktemp -d)"
      cd "$workdir"

      echo "Installing kubectl and Helm..."
      az aks install-cli --only-show-errors
      curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

      echo "Connecting to AKS..."
      for attempt in $(seq 1 18); do
        if az aks get-credentials --admin --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --overwrite-existing --only-show-errors; then
          break
        fi
        if [ "$attempt" = "18" ]; then
          echo "Unable to get AKS credentials after waiting for role assignment propagation." >&2
          exit 1
        fi
        sleep 20
      done

      manifest_base="${RAW_CONTENT_BASE_URL}/workloads/search-analytics/opensearch/kubernetes"
      curl -fsSL "${manifest_base}/manifests/managed-csi-premium-storageclass.yaml" -o managed-csi-premium-storageclass.yaml
      curl -fsSL "${manifest_base}/manifests/namespace.yaml" -o namespace.yaml
      curl -fsSL "${manifest_base}/helm/manager-values.yaml" -o manager-values.yaml
      curl -fsSL "${manifest_base}/helm/data-values.yaml" -o data-values.yaml
      curl -fsSL "${manifest_base}/helm/dashboards-values.yaml" -o dashboards-values.yaml

      echo "Creating namespace, storage class, and secrets..."
      kubectl apply -f managed-csi-premium-storageclass.yaml
      kubectl apply -f namespace.yaml

      cookie_secret="$(openssl rand -hex 16)"
      kubectl create secret generic opensearch-admin-credentials \
        --namespace opensearch \
        --from-literal=password="$ADMIN_PASSWORD" \
        --dry-run=client -o yaml | kubectl apply -f -

      kubectl create secret generic opensearch-dashboards-auth \
        --namespace opensearch \
        --from-literal=username='admin' \
        --from-literal=password="$ADMIN_PASSWORD" \
        --from-literal=cookie="$cookie_secret" \
        --dry-run=client -o yaml | kubectl apply -f -

      kubectl create secret generic opensearch-snapshot-settings \
        --namespace opensearch \
        --from-literal=azure.client.default.account="$SNAPSHOT_STORAGE_ACCOUNT" \
        --dry-run=client -o yaml | kubectl apply -f -

      echo "Installing OpenSearch Helm releases..."
      helm repo add opensearch https://opensearch-project.github.io/helm-charts/
      helm repo update

      helm upgrade --install opensearch-manager opensearch/opensearch \
        --version "$OPENSEARCH_HELM_VERSION" \
        --namespace opensearch \
        --set-string "rbac.serviceAccountAnnotations.azure\\.workload\\.identity/client-id=$SNAPSHOT_IDENTITY_CLIENT_ID" \
        --values manager-values.yaml

      helm upgrade --install opensearch-data opensearch/opensearch \
        --version "$OPENSEARCH_HELM_VERSION" \
        --namespace opensearch \
        --set-string "rbac.serviceAccountAnnotations.azure\\.workload\\.identity/client-id=$SNAPSHOT_IDENTITY_CLIENT_ID" \
        --values data-values.yaml

      helm upgrade --install opensearch-dashboards opensearch/opensearch-dashboards \
        --version "$OPENSEARCH_DASHBOARDS_HELM_VERSION" \
        --namespace opensearch \
        --values dashboards-values.yaml

      echo "Waiting for OpenSearch and Dashboards readiness..."
      kubectl wait --for=condition=Ready pod -n opensearch -l app.kubernetes.io/component=opensearch-manager --timeout=900s
      kubectl wait --for=condition=Ready pod -n opensearch -l app.kubernetes.io/component=opensearch-data --timeout=900s
      kubectl wait --for=condition=Ready pod -n opensearch -l app.kubernetes.io/name=opensearch-dashboards --timeout=600s

      kubectl port-forward svc/opensearch-manager 9200:9200 -n opensearch >/tmp/opensearch-portal-port-forward.log 2>&1 &
      pf_pid="$!"
      trap 'kill "$pf_pid" 2>/dev/null || true' EXIT

      for attempt in $(seq 1 30); do
        if curl -sk -u "admin:${ADMIN_PASSWORD}" --max-time 2 https://127.0.0.1:9200 >/dev/null; then
          break
        fi
        if [ "$attempt" = "30" ]; then
          echo "OpenSearch API did not become reachable through port-forward." >&2
          exit 1
        fi
        sleep 2
      done

      echo "Registering and verifying Azure snapshot repository..."
      curl -sk -u "admin:${ADMIN_PASSWORD}" \
        -XPUT https://127.0.0.1:9200/_snapshot/azure-managed-identity \
        -H 'Content-Type: application/json' \
        -d "{\"type\":\"azure\",\"settings\":{\"client\":\"default\",\"container\":\"$SNAPSHOT_CONTAINER\"}}"

      curl -sk -u "admin:${ADMIN_PASSWORD}" \
        -XPOST https://127.0.0.1:9200/_snapshot/azure-managed-identity/_verify?pretty

      dashboards_ip=""
      for attempt in $(seq 1 60); do
        dashboards_ip="$(kubectl get svc opensearch-dashboards -n opensearch -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
        if [ -n "$dashboards_ip" ]; then
          break
        fi
        sleep 10
      done

      echo "Deployment complete."
      echo "Dashboards internal URL: ${dashboards_ip:+http://${dashboards_ip}:5601}"
      echo "Dashboards username: admin"
      echo "If you cannot reach the internal IP, run: kubectl port-forward svc/opensearch-dashboards 5601:5601 -n opensearch"
    '''
  }
  dependsOn: [
    deploymentScriptAksAdminRole
  ]
}

output deployedClusterName string = opensearchBaseline.outputs.deployedClusterName
output deployedSnapshotStorageAccount string = opensearchBaseline.outputs.deployedSnapshotStorageAccount
output dashboardsAccessNote string = 'OpenSearch Dashboards is exposed on an internal load balancer. Use kubectl get svc opensearch-dashboards -n opensearch to get the private IP, or port-forward svc/opensearch-dashboards 5601:5601.'
