# OpenSearch `az` CLI deployment path

Use this guide for the automation-first path. It assumes you want the Azure resource shape, Kubernetes assets, and Helm configuration tracked in source control.

## Prerequisites

- Azure CLI
- `kubectl`
- Helm 3.x
- Terraform 1.11+ if you want the Terraform path
- an Azure subscription with quota for AKS and managed disks

## Environment variables

```bash
export LOCATION=eastus
export RESOURCE_GROUP=rg-opensearch-aks-dev
export CLUSTER_NAME=aks-opensearch-dev
export DEPLOYMENT_NAME=opensearch-infra
export SNAPSHOT_STORAGE_ACCOUNT=opssnapdev001
export SNAPSHOT_CONTAINER=opensearch-snapshots
export OPENSEARCH_HELM_VERSION=3.6.0
export OPENSEARCH_DASHBOARDS_HELM_VERSION=3.2.0
```

## Option A: Bicep wrapper

Create the resource group and run the workload wrapper:

```bash
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"

az deployment group create \
  --name "$DEPLOYMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --template-file workloads/search-analytics/opensearch/infra/bicep/main.bicep \
  --parameters \
      clusterName="$CLUSTER_NAME" \
      location="$LOCATION" \
      snapshotStorageAccountName="$SNAPSHOT_STORAGE_ACCOUNT" \
      snapshotContainerName="$SNAPSHOT_CONTAINER"
```

This path relies on the shared AVM wrapper for the AKS baseline and optionally creates an Azure Storage account and container for snapshot use.
When snapshot storage is enabled, the wrapper also enables AKS workload identity, creates a user-assigned managed identity plus federated credentials for the manager and data service accounts, and disables shared-key access on the starter storage account.
The checked-in wrappers provision `systempool`, `osmgr`, and `osdata`. The dedicated `osmgr` and `osdata` pools start with three nodes each so the default Helm anti-affinity rules can place all manager and data replicas.

## Option B: Terraform wrapper

```bash
cd workloads/search-analytics/opensearch/infra/terraform
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform plan
terraform apply
```

The example `terraform.tfvars.example` wires the same baseline and optional snapshot storage account through the shared Terraform wrapper.
When snapshot storage is enabled, Terraform also creates the managed identity, federated credentials, and container-scoped RBAC assignment needed for the keyless snapshot path.

## Collect the snapshot workload identity output

If you kept snapshot storage enabled, capture the managed identity client ID from the deployment path you used:

```bash
# Bicep
export SNAPSHOT_IDENTITY_CLIENT_ID="$(az deployment group show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DEPLOYMENT_NAME" \
  --query 'properties.outputs.snapshotManagedIdentityClientId.value' \
  -o tsv)"

# Terraform
export SNAPSHOT_IDENTITY_CLIENT_ID="$(terraform output -raw snapshot_managed_identity_client_id)"
```

If you disabled snapshot storage here, create an equivalent user-assigned managed identity, matching federated credentials, and a `Storage Blob Data Contributor` assignment for your existing snapshot container before continuing.

## Connect to AKS

```bash
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME"
```

## Prepare the storage class, namespace, and secrets

```bash
kubectl apply -f workloads/search-analytics/opensearch/kubernetes/manifests/managed-csi-premium-storageclass.yaml
kubectl apply -f workloads/search-analytics/opensearch/kubernetes/manifests/namespace.yaml
kubectl create secret generic opensearch-admin-credentials \
  --namespace opensearch \
  --from-literal=password='<strong-admin-password>' \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic opensearch-dashboards-auth \
  --namespace opensearch \
  --from-literal=username='admin' \
  --from-literal=password='<strong-admin-password>' \
  --from-literal=cookie='<32-character-cookie-secret>' \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic opensearch-snapshot-settings \
  --namespace opensearch \
  --from-literal=azure.client.default.account="$SNAPSHOT_STORAGE_ACCOUNT" \
  --dry-run=client -o yaml | kubectl apply -f -
```

Create real secrets instead of applying the example YAML files unchanged.
The storage class manifest matches the AKS built-in `managed-csi-premium` definition, so `kubectl apply` stays safe whether the class already exists or needs to be created.
The snapshot settings secret loads the storage account name into the OpenSearch keystore, which is required because `azure.client.default.account` is a secure setting.
The namespace manifest uses the `privileged` Pod Security profile because the checked-in Helm values enable the chart's sysctl init container to raise `vm.max_map_count` before the OpenSearch JVM starts.

## Install manager nodes

```bash
helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm repo update

helm upgrade --install opensearch-manager opensearch/opensearch \
  --version "$OPENSEARCH_HELM_VERSION" \
  --namespace opensearch \
  --set-string "rbac.serviceAccountAnnotations.azure\\.workload\\.identity/client-id=$SNAPSHOT_IDENTITY_CLIENT_ID" \
  --values workloads/search-analytics/opensearch/kubernetes/helm/manager-values.yaml
```

## Install data nodes

```bash
helm upgrade --install opensearch-data opensearch/opensearch \
  --version "$OPENSEARCH_HELM_VERSION" \
  --namespace opensearch \
  --set-string "rbac.serviceAccountAnnotations.azure\\.workload\\.identity/client-id=$SNAPSHOT_IDENTITY_CLIENT_ID" \
  --values workloads/search-analytics/opensearch/kubernetes/helm/data-values.yaml
```

## Install Dashboards

```bash
helm upgrade --install opensearch-dashboards opensearch/opensearch-dashboards \
  --version "$OPENSEARCH_DASHBOARDS_HELM_VERSION" \
  --namespace opensearch \
  --values workloads/search-analytics/opensearch/kubernetes/helm/dashboards-values.yaml
```

The checked-in manager and data values install `repository-azure` at pod startup, load the storage account name from the `opensearch-snapshot-settings` secret into the OpenSearch keystore, enable managed identity token auth in `opensearch.yml`, and create workload-identity service accounts when you pass the managed identity client ID with `--set-string`.
If your cluster cannot download plugins during pod start, bake `repository-azure` into a custom image before installing.

## Register the managed-identity snapshot repository

After the pods are ready and you have port-forwarded the manager service, register the Azure repository without any storage account keys:

```bash
kubectl port-forward svc/opensearch-manager 9200:9200 -n opensearch

curl -k -u "admin:<your-admin-password>" \
  -XPUT https://127.0.0.1:9200/_snapshot/azure-managed-identity \
  -H 'Content-Type: application/json' \
  -d "{\"type\":\"azure\",\"settings\":{\"client\":\"default\",\"container\":\"$SNAPSHOT_CONTAINER\"}}"
```

Add a `base_path` only if you want snapshots under a subdirectory of the container.

## Validate the deployment

```bash
kubectl get pods -n opensearch
kubectl get pvc -n opensearch
kubectl get svc -n opensearch
kubectl describe svc opensearch-dashboards -n opensearch
```

Check for:

- manager pods scheduled and healthy
- data pods bound to persistent volumes
- Dashboards service receiving an internal IP
- no unintended public endpoint for the OpenSearch API
- successful `azure-managed-identity` repository registration without any storage account key or SAS token

For API validation without exposing OpenSearch publicly:

```bash
kubectl port-forward svc/opensearch-manager 9200:9200 -n opensearch
curl -k https://127.0.0.1:9200
```

## Implementation notes

- keep the OpenSearch API internal by default
- use dedicated node pools and align them to the example selectors and tolerations
- the starter snapshot storage account disables shared-key access and the checked-in Helm values load `azure.client.default.account` from the `opensearch-snapshot-settings` secret while keeping `azure.client.default.token_credential_type: managed_identity` in `opensearch.yml`
- the wrapper provisions the Azure side of the snapshot path, but repository registration is still a per-cluster operator step
