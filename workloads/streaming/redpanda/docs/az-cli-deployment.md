# Redpanda `az` CLI deployment path

Use this guide for the automation-first path. It assumes you want the Azure resource shape, Kubernetes assets, and Helm configuration tracked in source control.

## Prerequisites

- Azure CLI
- `kubectl`
- Helm 3.10+
- Terraform 1.11+ if you want the Terraform path
- an Azure subscription with quota for AKS and Premium SSD-backed managed disks

## Environment variables

```bash
export LOCATION=eastus
export RESOURCE_GROUP=rg-redpanda-aks-dev
export CLUSTER_NAME=aks-redpanda-dev
export SYSTEM_POOL_VM_SIZE=Standard_D4ds_v5
export BROKER_POOL_VM_SIZE=Standard_D8ds_v5
export CERT_MANAGER_VERSION=v1.17.2
export REDPANDA_HELM_VERSION=26.1.1
```

The default broker pool size in the repo is `Standard_D8ds_v5`, which is a concrete x86_64 starter choice with SSE4.2 support. If you substitute a different VM size, keep the same CPU capability and keep at least three broker nodes.

## Option A: Bicep wrapper

Create the resource group and run the workload wrapper:

```bash
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file workloads/streaming/redpanda/infra/bicep/main.bicep \
  --parameters \
      clusterName="$CLUSTER_NAME" \
      location="$LOCATION" \
      systemPoolVmSize="$SYSTEM_POOL_VM_SIZE" \
      brokerPoolVmSize="$BROKER_POOL_VM_SIZE" \
      brokerPoolCount=3
```

This path relies on the shared AVM wrapper for the AKS baseline and provisions both `systempool` and `rpbroker`.

## Option B: Terraform wrapper

```bash
cd workloads/streaming/redpanda/infra/terraform
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform plan
terraform apply
```

The example `terraform.tfvars.example` wires the same `systempool` + `rpbroker` baseline through the shared Terraform wrapper.

## Connect to AKS

```bash
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME"
```

## Install cert-manager

The checked-in Redpanda values keep TLS enabled, so install cert-manager before the Helm release:

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml

kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-webhook -n cert-manager
```

## Prepare the storage class and namespace

```bash
kubectl apply -f workloads/streaming/redpanda/kubernetes/manifests/managed-csi-premium-storageclass.yaml
kubectl apply -f workloads/streaming/redpanda/kubernetes/manifests/namespace.yaml
```

The storage class manifest matches the AKS built-in `managed-csi-premium` definition and keeps the Premium SSD-backed class expected by the checked-in values. The namespace uses the `privileged` Pod Security profile because `tuning.tune_aio_events` is enabled in the starter values.

## Install Redpanda

```bash
helm repo add redpanda https://charts.redpanda.com
helm repo update

helm upgrade --install redpanda redpanda/redpanda \
  --version "$REDPANDA_HELM_VERSION" \
  --namespace redpanda \
  --values workloads/streaming/redpanda/kubernetes/helm/redpanda-values.yaml

kubectl rollout status statefulset/redpanda -n redpanda --timeout=15m
```

## Validate the deployment

```bash
kubectl get pods -n redpanda -o wide
kubectl get pvc -n redpanda
kubectl get certificates -n redpanda
kubectl get svc -n redpanda
```

For admin API validation without enabling external listeners:

```bash
kubectl port-forward svc/redpanda 9644:9644 -n redpanda
curl -sk https://127.0.0.1:9644/v1/status/ready
curl -sk https://127.0.0.1:9644/v1/cluster/health_overview
```

## Enable AKS cluster autoscaler (recommended)

After validating the deployment, enable the AKS cluster autoscaler on the `rpbroker` pool so that when you manually scale the StatefulSet, nodes are provisioned automatically:

```bash
az aks nodepool update \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --name rpbroker \
  --enable-cluster-autoscaler \
  --min-count 3 \
  --max-count 6
```

The cluster autoscaler does **not** automatically scale the Redpanda StatefulSet. It only ensures nodes exist when brokers are added or drained. The `3–6` range is a starter ceiling — adjust based on quota and expected throughput.

See `docs/operations.md` for broker scaling procedures, PVC expansion, and decommission runbooks.

## Tear down the environment

For the Bicep path, deleting the resource group removes the full AKS environment:

```bash
az group delete \
  --name "$RESOURCE_GROUP" \
  --yes
```

For the Terraform path, uninstall the Redpanda workload before `terraform destroy` so AKS can drain the dedicated `rpbroker` pool cleanly:

```bash
helm uninstall redpanda -n redpanda
kubectl delete pvc --all -n redpanda --wait=false
kubectl delete namespace redpanda --wait=true --timeout=600s

cd workloads/streaming/redpanda/infra/terraform
terraform destroy -refresh=false
```

## Implementation notes

- keep the `rpbroker` pool at 3 or more nodes so each broker can land on its own node
- treat `kubectl get pvc` as a first-class validation step; a broker is not healthy until its disk is attached and `Bound`
- keep external listeners disabled until you have a stable advertised-address design for each broker
- uninstall the Helm release before deleting the Terraform-managed cluster or node pool so broker eviction does not block teardown
- keep tiered storage disabled until the Azure Blob identity and RBAC plan is ready, and use managed identity rather than shared keys when you do enable it
