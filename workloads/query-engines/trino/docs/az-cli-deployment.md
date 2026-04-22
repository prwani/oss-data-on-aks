# Trino `az` CLI deployment path

Use this guide for the automation-first path. It keeps the Azure resource shape, Kubernetes assets, and Helm configuration tracked in source control.

## Prerequisites

- Azure CLI
- `kubectl`
- Helm 3.x
- Terraform 1.11+ if you want the Terraform path
- an Azure subscription with quota for AKS node pools sized for distributed query workloads

## Environment variables

```bash
export LOCATION=eastus
export RESOURCE_GROUP=rg-trino-aks-dev
export CLUSTER_NAME=aks-trino-dev
export TRINO_HELM_VERSION=1.42.1
```

## Option A: Bicep wrapper

Create the resource group and run the workload wrapper:

```bash
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

az deployment group create --resource-group "$RESOURCE_GROUP" --template-file workloads/query-engines/trino/infra/bicep/main.bicep --parameters clusterName="$CLUSTER_NAME" location="$LOCATION"
```

This path relies on the shared AKS AVM wrapper and creates `systempool` plus one dedicated `trino` pool with three nodes.

## Option B: Terraform wrapper

```bash
cd workloads/query-engines/trino/infra/terraform
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform plan
terraform apply
```

The example `terraform.tfvars.example` wires the same system and dedicated pool layout through the shared Terraform wrapper.

## Connect to AKS

```bash
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME"
```

## Prepare the namespace

```bash
kubectl apply -f workloads/query-engines/trino/kubernetes/manifests/namespace.yaml
```

The starter Trino blueprint keeps the checked-in catalog surface to `tpch`, so no bootstrap secret is required for the first deployment.

## Install Trino

```bash
helm repo add trino https://trinodb.github.io/charts/
helm repo update

helm upgrade --install trino trino/trino --version "$TRINO_HELM_VERSION" --namespace trino --values workloads/query-engines/trino/kubernetes/helm/trino-values.yaml
```

## Validate the deployment

```bash
kubectl get deploy,pods,svc -n trino
kubectl describe deploy trino-worker -n trino

kubectl exec deploy/trino-coordinator -n trino -- trino --execute "SHOW CATALOGS"

kubectl exec deploy/trino-coordinator -n trino -- trino --execute "SELECT node_id, coordinator FROM system.runtime.nodes"

kubectl exec deploy/trino-coordinator -n trino -- trino --execute "SELECT count(*) AS nations FROM tpch.tiny.nation"
```

For API validation without exposing Trino publicly:

```bash
kubectl port-forward svc/trino 8080:8080 -n trino
curl http://127.0.0.1:8080/v1/info
```

## Internal load balancer path

If teams need VNet-shared access instead of port-forward, override the service to an internal Azure load balancer rather than making it public:

```yaml
service:
  type: LoadBalancer
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
```

Keep that as an environment-specific override file instead of changing the checked-in default, so the blueprint stays private by default.

## Implementation notes

- the coordinator service is the only client entry point in this starter blueprint
- worker pods tolerate the `dedicated=trino:NoSchedule` taint and use node-local `emptyDir` spill space
- `tpch` is included so the blueprint is runnable without Hive Metastore, object storage, or other external dependencies
- when you add Azure Storage-backed catalogs, use workload identity and managed identity auth rather than shared keys
