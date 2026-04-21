# OpenSearch `az` CLI deployment path

Use this guide for the automation-first path. It assumes you want the Azure resource shape, Kubernetes assets, and Helm configuration tracked in source control.

## Prerequisites

- Azure CLI
- `kubectl`
- Helm 3.x
- Terraform 1.6+ if you want the Terraform path
- an Azure subscription with quota for AKS and managed disks

## Environment variables

```bash
export LOCATION=eastus
export RESOURCE_GROUP=rg-opensearch-aks-dev
export CLUSTER_NAME=aks-opensearch-dev
export SNAPSHOT_STORAGE_ACCOUNT=opssnapdev001
```

## Option A: Bicep wrapper

Create the resource group and run the workload wrapper:

```bash
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file workloads/search-analytics/opensearch/infra/bicep/main.bicep \
  --parameters \
      clusterName="$CLUSTER_NAME" \
      location="$LOCATION" \
      snapshotStorageAccountName="$SNAPSHOT_STORAGE_ACCOUNT"
```

This path relies on the shared AVM wrapper for the AKS baseline and optionally creates an Azure Storage account and container for snapshot use.

## Option B: Terraform wrapper

```bash
cd workloads/search-analytics/opensearch/infra/terraform
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform plan
terraform apply
```

The example `terraform.tfvars.example` wires the same baseline and optional snapshot storage account through the shared Terraform wrapper.

## Connect to AKS

```bash
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME"
```

## Prepare the namespace and secrets

```bash
kubectl apply -f workloads/search-analytics/opensearch/kubernetes/manifests/namespace.yaml
kubectl apply -f workloads/search-analytics/opensearch/kubernetes/manifests/opensearch-admin-credentials.example.yaml
kubectl apply -f workloads/search-analytics/opensearch/kubernetes/manifests/opensearch-dashboards-auth.example.yaml
```

Replace the example secret values before applying them in a real environment.

## Install manager nodes

```bash
helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm repo update

helm upgrade --install opensearch-manager opensearch/opensearch \
  --namespace opensearch \
  --values workloads/search-analytics/opensearch/kubernetes/helm/manager-values.yaml
```

## Install data nodes

```bash
helm upgrade --install opensearch-data opensearch/opensearch \
  --namespace opensearch \
  --values workloads/search-analytics/opensearch/kubernetes/helm/data-values.yaml
```

## Install Dashboards

```bash
helm upgrade --install opensearch-dashboards opensearch/opensearch-dashboards \
  --namespace opensearch \
  --values workloads/search-analytics/opensearch/kubernetes/helm/dashboards-values.yaml
```

## Validate the deployment

```bash
kubectl get pods -n opensearch
kubectl get pvc -n opensearch
kubectl get svc -n opensearch
kubectl describe svc opensearch-dashboards -n opensearch
```

For API validation without exposing OpenSearch publicly:

```bash
kubectl port-forward svc/opensearch-manager 9200:9200 -n opensearch
curl -k https://127.0.0.1:9200
```

## Implementation notes

- keep the OpenSearch API internal by default
- use dedicated node pools and align them to the example selectors and tolerations
- treat the snapshot storage account as the external recovery target, not as proof that snapshot registration is already fully automated
