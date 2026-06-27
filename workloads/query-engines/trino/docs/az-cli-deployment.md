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
export LOCATION=swedencentral
export RESOURCE_GROUP=rg-trino-aks-dev
export CLUSTER_NAME=aks-trino-dev
export TRINO_HELM_VERSION=1.42.1
```

## Select the Azure subscription

```bash
az account set --subscription "ME-M365CPI88726844-prafullawani-1"
az account show --query "{name:name,id:id,tenantId:tenantId}" -o table
```

## Option A: Bicep wrapper

Create the resource group and run the workload wrapper. This path provisions ADLS Gen2, the lakehouse managed identity, workload identity federation, AKS, the `trino` node pool, and the `catalog` node pool.

```bash
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

az deployment group create --resource-group "$RESOURCE_GROUP" --template-file workloads/query-engines/trino/infra/bicep/main.bicep --parameters clusterName="$CLUSTER_NAME" location="$LOCATION"
```

This path relies on the shared AKS AVM wrapper and creates `systempool`, one dedicated `trino` pool with three nodes, and one `catalog` pool for the Iceberg REST catalog.

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

The starter Trino blueprint validates the `tpcds` source catalog, so no bootstrap source data is required for the first deployment. The upstream chart may also render its default `tpch` catalog; this blueprint uses `tpcds` for benchmark generation.

## Install Trino

```bash
helm repo add trino https://trinodb.github.io/charts/
helm repo update

helm upgrade --install trino trino/trino --version "$TRINO_HELM_VERSION" --namespace trino --values workloads/query-engines/trino/kubernetes/helm/trino-values.yaml
```

## Install the Iceberg REST catalog

Use the assets in `workloads/query-engines/trino/kubernetes/iceberg-rest-catalog` after creating a PostgreSQL backing database for Polaris metadata.

```bash
kubectl apply -f workloads/query-engines/trino/kubernetes/iceberg-rest-catalog/namespace.yaml

kubectl create secret generic polaris-postgresql -n iceberg-catalog \
  --from-literal=username="$POLARIS_POSTGRES_USER" \
  --from-literal=password="$POLARIS_POSTGRES_PASSWORD" \
  --from-literal=jdbcUrl="$POLARIS_POSTGRES_JDBC_URL"

helm repo add apache-polaris https://downloads.apache.org/polaris/helm-chart/
helm repo update

helm upgrade --install polaris apache-polaris/polaris \
  --namespace iceberg-catalog \
  --values workloads/query-engines/trino/kubernetes/iceberg-rest-catalog/polaris-values.example.yaml
```

Copy `trino-iceberg-adls-values.example.yaml`, replace the storage account and identity placeholders from the deployment outputs, then upgrade Trino with the override.

## Validate the deployment

```bash
kubectl get deploy,pods,svc -n trino
kubectl describe deploy trino-worker -n trino

kubectl exec deploy/trino-coordinator -n trino -- trino --execute "SHOW CATALOGS"

kubectl exec deploy/trino-coordinator -n trino -- trino --execute "SELECT node_id, coordinator FROM system.runtime.nodes"

kubectl exec deploy/trino-coordinator -n trino -- trino --execute "SELECT count(*) AS customers FROM tpcds.tiny.customer"
```

When the Iceberg override is enabled, validate persisted ADLS Gen2 data:

```bash
kubectl exec deploy/trino-coordinator -n trino -- trino --execute "SHOW SCHEMAS FROM iceberg"
kubectl exec deploy/trino-coordinator -n trino -- trino --execute "SELECT count(*) AS customers FROM iceberg.tpcds_sf1.customer"
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
- `tpcds` is included so the blueprint can generate benchmark rows without downloading files
- the Iceberg REST catalog is the production-style catalog path for persisted ADLS Gen2 tables
- Azure Storage-backed catalogs must use workload identity and managed identity auth rather than shared keys
