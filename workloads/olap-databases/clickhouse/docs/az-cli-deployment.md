# ClickHouse `az` CLI deployment path

Use this guide for the automation-first path. It keeps the Azure resource shape, Kubernetes assets, and Helm configuration tracked in source control.

## Prerequisites

- Azure CLI
- `kubectl`
- Helm 3.x
- Terraform 1.11+ if you want the Terraform path
- an Azure subscription with quota for AKS node pools and managed disks sized for OLAP workloads

## Environment variables

```bash
export LOCATION=eastus
export RESOURCE_GROUP=rg-clickhouse-aks-dev
export CLUSTER_NAME=aks-clickhouse-dev
export CLICKHOUSE_HELM_VERSION=9.4.7
```

## Option A: Bicep wrapper

```bash
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

az deployment group create --resource-group "$RESOURCE_GROUP" --template-file workloads/olap-databases/clickhouse/infra/bicep/main.bicep --parameters clusterName="$CLUSTER_NAME" location="$LOCATION"
```

This path relies on the shared AKS AVM wrapper and creates `systempool` plus one dedicated `clickhouse` pool with three nodes.

## Option B: Terraform wrapper

```bash
cd workloads/olap-databases/clickhouse/infra/terraform
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform plan
terraform apply
```

## Connect to AKS

```bash
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME"
```

## Prepare the storage class, namespace, and runtime secret

```bash
kubectl apply -f workloads/olap-databases/clickhouse/kubernetes/manifests/managed-csi-premium-storageclass.yaml
kubectl apply -f workloads/olap-databases/clickhouse/kubernetes/manifests/namespace.yaml

kubectl create secret generic clickhouse-auth --namespace clickhouse --from-literal=admin-password="$(openssl rand -base64 32 | tr -d '\n')"
```

The checked-in Helm values reference `clickhouse-auth` and key `admin-password`, so the password stays outside source control.

## Install ClickHouse

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm upgrade --install clickhouse bitnami/clickhouse --version "$CLICKHOUSE_HELM_VERSION" --namespace clickhouse --values workloads/olap-databases/clickhouse/kubernetes/helm/clickhouse-values.yaml
```

## Validate the deployment

```bash
kubectl get statefulset,pods,pvc,svc -n clickhouse
export CLICKHOUSE_PASSWORD=$(kubectl get secret clickhouse-auth -n clickhouse -o jsonpath='{.data.admin-password}' | base64 --decode)

kubectl port-forward svc/clickhouse 8123:8123 9000:9000 -n clickhouse
curl http://127.0.0.1:8123/ping
curl --user default:$CLICKHOUSE_PASSWORD "http://127.0.0.1:8123/?query=SELECT%20version()"
curl --user default:$CLICKHOUSE_PASSWORD "http://127.0.0.1:8123/?query=SELECT%20cluster%2Cshard_num%2Creplica_num%2Chost_name%20FROM%20system.clusters%20WHERE%20cluster%3D%27aks-clickhouse%27%20FORMAT%20PrettyCompact"
```

## Internal load balancer path

If a team needs shared access inside a private network instead of port-forward, override the service to an internal Azure load balancer rather than exposing it publicly:

```yaml
service:
  type: LoadBalancer
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
```

Keep Keeper on `ClusterIP` and leave the checked-in default private.

## Implementation notes

- the pinned values create 2 shards × 2 replicas plus a 3-node Keeper quorum
- each ClickHouse and Keeper pod gets its own Premium SSD-backed PVC
- the chart expects the secret `clickhouse-auth` with key `admin-password`
- when you add backup storage or Azure-integrated engines later, use managed identity auth rather than storage account keys
