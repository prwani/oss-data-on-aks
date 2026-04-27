#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKLOAD_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPO_ROOT="$(cd "$WORKLOAD_DIR/../../.." && pwd)"

prompt_default() {
  local name="$1"
  local prompt="$2"
  local default_value="$3"
  local current_value="${!name:-}"

  if [ -n "$current_value" ]; then
    return
  fi

  read -r -p "$prompt [$default_value]: " current_value
  export "$name=${current_value:-$default_value}"
}

prompt_secret() {
  local name="$1"
  local prompt="$2"
  local current_value="${!name:-}"

  if [ -n "$current_value" ]; then
    return
  fi

  read -r -s -p "$prompt: " current_value
  printf '\n'
  if [ -z "$current_value" ]; then
    echo "A value is required for $name." >&2
    exit 1
  fi
  export "$name=$current_value"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

wait_for_dashboards_ip() {
  local dashboards_ip=""
  for _ in $(seq 1 60); do
    dashboards_ip="$(kubectl get svc opensearch-dashboards -n opensearch -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
    if [ -n "$dashboards_ip" ]; then
      printf '%s' "$dashboards_ip"
      return
    fi
    sleep 10
  done
}

require_command az
require_command kubectl
require_command helm
require_command curl
require_command openssl

prompt_default DEPLOY_ENGINE "Deployment engine (bicep or terraform)" "bicep"
prompt_default LOCATION "Azure region" "swedencentral"
prompt_default RESOURCE_GROUP "Resource group name" "rg-opensearch-aks-dev"
prompt_default CLUSTER_NAME "AKS cluster name" "aks-opensearch-dev"
prompt_default SNAPSHOT_STORAGE_ACCOUNT "Globally unique snapshot storage account name" "opssnap$(date +%m%d%H%M)"
prompt_default SNAPSHOT_CONTAINER "Snapshot container name" "opensearch-snapshots"
prompt_secret ADMIN_PASSWORD "OpenSearch admin password"

COOKIE_SECRET="${COOKIE_SECRET:-$(openssl rand -hex 16)}"
OPENSEARCH_HELM_VERSION="${OPENSEARCH_HELM_VERSION:-3.6.0}"
OPENSEARCH_DASHBOARDS_HELM_VERSION="${OPENSEARCH_DASHBOARDS_HELM_VERSION:-3.2.0}"
AUTO_APPROVE="${AUTO_APPROVE:-true}"

case "$DEPLOY_ENGINE" in
  bicep | terraform) ;;
  *)
    echo "DEPLOY_ENGINE must be 'bicep' or 'terraform'." >&2
    exit 1
    ;;
esac

echo "Step 1/7: Deploying Azure baseline with $DEPLOY_ENGINE..."
if [ "$DEPLOY_ENGINE" = "bicep" ]; then
  az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION"

  az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$WORKLOAD_DIR/infra/bicep/main.bicep" \
    --parameters \
      clusterName="$CLUSTER_NAME" \
      location="$LOCATION" \
      snapshotStorageAccountName="$SNAPSHOT_STORAGE_ACCOUNT" \
      snapshotContainerName="$SNAPSHOT_CONTAINER"

  SNAPSHOT_IDENTITY_CLIENT_ID="$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name main \
    --query 'properties.outputs.snapshotManagedIdentityClientId.value' \
    -o tsv)"
else
  require_command terraform
  ENVIRONMENT_NAME="${ENVIRONMENT_NAME:-dev}"
  TF_ARGS=(
    -var="environment_name=$ENVIRONMENT_NAME"
    -var="location=$LOCATION"
    -var="resource_group_name=$RESOURCE_GROUP"
    -var="cluster_name=$CLUSTER_NAME"
    -var="snapshot_storage_account_name=$SNAPSHOT_STORAGE_ACCOUNT"
    -var="snapshot_container_name=$SNAPSHOT_CONTAINER"
  )

  terraform -chdir="$WORKLOAD_DIR/infra/terraform" init -backend=false
  if [ "$AUTO_APPROVE" = "true" ]; then
    terraform -chdir="$WORKLOAD_DIR/infra/terraform" apply -auto-approve "${TF_ARGS[@]}"
  else
    terraform -chdir="$WORKLOAD_DIR/infra/terraform" apply "${TF_ARGS[@]}"
  fi

  SNAPSHOT_IDENTITY_CLIENT_ID="$(terraform -chdir="$WORKLOAD_DIR/infra/terraform" output -raw snapshot_managed_identity_client_id)"
fi

echo "Step 2/7: Connecting to AKS and creating the namespace..."
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" \
  --overwrite-existing

kubectl apply -f "$WORKLOAD_DIR/kubernetes/manifests/managed-csi-premium-storageclass.yaml"
kubectl apply -f "$WORKLOAD_DIR/kubernetes/manifests/namespace.yaml"

echo "Step 3/7: Creating bootstrap secrets..."
kubectl create secret generic opensearch-admin-credentials \
  --namespace opensearch \
  --from-literal=password="$ADMIN_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic opensearch-dashboards-auth \
  --namespace opensearch \
  --from-literal=username='admin' \
  --from-literal=password="$ADMIN_PASSWORD" \
  --from-literal=cookie="$COOKIE_SECRET" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic opensearch-snapshot-settings \
  --namespace opensearch \
  --from-literal=azure.client.default.account="$SNAPSHOT_STORAGE_ACCOUNT" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Step 4/7: Installing the manager tier..."
helm repo add opensearch https://opensearch-project.github.io/helm-charts/ >/dev/null 2>&1 || true
helm repo update

helm upgrade --install opensearch-manager opensearch/opensearch \
  --version "$OPENSEARCH_HELM_VERSION" \
  --namespace opensearch \
  --set-string "rbac.serviceAccountAnnotations.azure\\.workload\\.identity/client-id=$SNAPSHOT_IDENTITY_CLIENT_ID" \
  --values "$WORKLOAD_DIR/kubernetes/helm/manager-values.yaml"

echo "Step 5/7: Installing the data tier..."
helm upgrade --install opensearch-data opensearch/opensearch \
  --version "$OPENSEARCH_HELM_VERSION" \
  --namespace opensearch \
  --set-string "rbac.serviceAccountAnnotations.azure\\.workload\\.identity/client-id=$SNAPSHOT_IDENTITY_CLIENT_ID" \
  --values "$WORKLOAD_DIR/kubernetes/helm/data-values.yaml"

echo "Step 6/7: Installing OpenSearch Dashboards..."
helm upgrade --install opensearch-dashboards opensearch/opensearch-dashboards \
  --version "$OPENSEARCH_DASHBOARDS_HELM_VERSION" \
  --namespace opensearch \
  --values "$WORKLOAD_DIR/kubernetes/helm/dashboards-values.yaml"

echo "Step 7/7: Waiting for readiness and validating the deployment..."
kubectl wait --for=condition=Ready pod -n opensearch -l app.kubernetes.io/component=opensearch-manager --timeout=900s
kubectl wait --for=condition=Ready pod -n opensearch -l app.kubernetes.io/component=opensearch-data --timeout=900s
kubectl wait --for=condition=Ready pod -n opensearch -l app.kubernetes.io/name=opensearch-dashboards --timeout=600s

kubectl port-forward svc/opensearch-manager 9200:9200 -n opensearch >/tmp/opensearch-deploy-port-forward.log 2>&1 &
PORT_FORWARD_PID=$!
trap 'kill "$PORT_FORWARD_PID" 2>/dev/null || true' EXIT

for _ in $(seq 1 30); do
  if curl -sk -u "admin:$ADMIN_PASSWORD" --max-time 2 https://127.0.0.1:9200 >/dev/null; then
    break
  fi
  sleep 2
done

curl -sk -u "admin:$ADMIN_PASSWORD" \
  -XPUT https://127.0.0.1:9200/_snapshot/azure-managed-identity \
  -H 'Content-Type: application/json' \
  -d "{\"type\":\"azure\",\"settings\":{\"client\":\"default\",\"container\":\"$SNAPSHOT_CONTAINER\"}}"

curl -sk -u "admin:$ADMIN_PASSWORD" \
  -XPOST https://127.0.0.1:9200/_snapshot/azure-managed-identity/_verify?pretty

DASHBOARDS_IP="$(wait_for_dashboards_ip)"

cat <<EOF

OpenSearch deployment complete.

Resource group: $RESOURCE_GROUP
AKS cluster: $CLUSTER_NAME
OpenSearch API: kubectl port-forward svc/opensearch-manager 9200:9200 -n opensearch
Dashboards internal URL: ${DASHBOARDS_IP:+http://$DASHBOARDS_IP:5601}
Dashboards local test URL: kubectl port-forward svc/opensearch-dashboards 5601:5601 -n opensearch, then open http://127.0.0.1:5601
Dashboards username: admin
Dashboards password: the admin password you entered for this script
EOF
