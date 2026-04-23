# Apache Flink `az` CLI deployment path

Use this path when you want the Azure resource shape, operator install, and sample Flink job captured as code.

## Prerequisites

- Azure CLI
- `kubectl`
- Helm 3.x
- Terraform 1.11+ if you want the Terraform path
- an AKS version compatible with the official Flink Kubernetes Operator chart `1.10.0`

## Environment variables

```bash
export LOCATION=eastus
export RESOURCE_GROUP=rg-apache-flink-aks-dev
export CLUSTER_NAME=aks-apache-flink-dev
export FLINK_NAMESPACE=flink
export FLINK_OPERATOR_NAMESPACE=flink-operator
export FLINK_OPERATOR_RELEASE=flink-kubernetes-operator
export FLINK_OPERATOR_HELM_VERSION=1.10.0
```

## Option A: Bicep wrapper

```bash
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file workloads/distributed-processing/apache-flink/infra/bicep/main.bicep \
  --parameters \
      clusterName="$CLUSTER_NAME" \
      location="$LOCATION"
```

This wrapper creates the shared AKS baseline plus the dedicated `flink` user pool defined for the workload.

The checked-in wrappers pin the `flink` pool to **Managed** OS disks so `Standard_D8ds_v5` does not fall back to AKS's ephemeral OS disk default, which can trigger overconstrained allocation failures in `swedencentral`.

## Option B: Terraform wrapper

```bash
cd workloads/distributed-processing/apache-flink/infra/terraform
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform plan
terraform apply
```

## Connect to AKS

```bash
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME"
```

## Create the workload namespace and RBAC

```bash
kubectl apply -f workloads/distributed-processing/apache-flink/kubernetes/manifests/namespace.yaml
kubectl apply -f workloads/distributed-processing/apache-flink/kubernetes/manifests/flink-serviceaccount-rbac.yaml
```

## Install the Flink Kubernetes Operator

```bash
helm repo add flink-kubernetes-operator https://archive.apache.org/dist/flink/flink-kubernetes-operator-1.10.0/
helm repo update

helm upgrade --install "$FLINK_OPERATOR_RELEASE" flink-kubernetes-operator/flink-kubernetes-operator \
  --version "$FLINK_OPERATOR_HELM_VERSION" \
  --namespace "$FLINK_OPERATOR_NAMESPACE" \
  --create-namespace \
  --values workloads/distributed-processing/apache-flink/kubernetes/helm/operator-values.yaml
```

The checked-in values pin the operator to the `systempool` node pool and tell it to watch only the `flink` namespace.

## Submit the sample FlinkDeployment

The sample runs the bundled WordCount jar as a bounded smoke test. It validates operator health, CRD reconciliation, and pod placement on the dedicated `flink` pool. It finishes quickly and does not exercise long-running checkpoint or autoscaler behavior.

```bash
kubectl apply -f workloads/distributed-processing/apache-flink/kubernetes/manifests/flink-word-count.yaml
```

## Validate the deployment

```bash
# Operator health
kubectl get pods -n "$FLINK_OPERATOR_NAMESPACE"
kubectl get crd flinkdeployments.flink.apache.org

# FlinkDeployment status
kubectl get flinkdeployments -n "$FLINK_NAMESPACE"
kubectl describe flinkdeployment flink-word-count -n "$FLINK_NAMESPACE"

# Pod placement
kubectl get pods -n "$FLINK_NAMESPACE" -o wide

# JobManager logs
kubectl logs deploy/flink-word-count -n "$FLINK_NAMESPACE" -c flink-main-container
```

Because the sample WordCount job is bounded, the FlinkDeployment may move from `RUNNING` to `FINISHED` quickly. Treat either state as a successful smoke test as long as the operator reconciles the resource, the JobManager becomes ready, and the TaskManagers land on the dedicated `flink` pool.

For a live Flink Web UI check while the job is still running:

```bash
kubectl port-forward svc/flink-word-count-rest 8081:8081 -n "$FLINK_NAMESPACE"
```

Then open `http://localhost:8081` to see the Flink dashboard. Because the sample is bounded, you may need to submit it again quickly to catch the UI while it is still alive.

## Enable AKS cluster autoscaler (recommended)

After the deployment is validated, enable the AKS cluster autoscaler on the `flink` pool to support node-level elasticity for the Flink operator autoscaler:

```bash
az aks nodepool update \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --name flink \
  --enable-cluster-autoscaler \
  --min-count 3 \
  --max-count 10
```

This allows the AKS cluster to add nodes when the Flink operator autoscaler requests more TaskManager pods than the current pool can schedule.

## Cleanup

Delete the FlinkDeployment to stop the job and remove all associated pods:

```bash
kubectl delete flinkdeployment flink-word-count -n "$FLINK_NAMESPACE"
```

To take a savepoint before deleting (requires durable storage and `upgradeMode: savepoint`):

```bash
kubectl patch flinkdeployment flink-word-count -n "$FLINK_NAMESPACE" --type merge \
  -p '{"spec":{"job":{"savepointTriggerNonce": '$(date +%s)' }}}'
```

> **Note:** the checked-in starter uses `upgradeMode: stateless` with local `emptyDir` storage, so savepoints are not durable. Configure ADLS Gen2 and set `upgradeMode: savepoint` before relying on savepoint-based recovery.

If you are tearing the whole environment down after validation, remove the operator and namespaces before deleting AKS:

```bash
helm uninstall "$FLINK_OPERATOR_RELEASE" -n "$FLINK_OPERATOR_NAMESPACE"
kubectl delete namespace "$FLINK_NAMESPACE" --wait=true --timeout=600s
kubectl delete namespace "$FLINK_OPERATOR_NAMESPACE" --wait=true --timeout=600s
```

For the Bicep path, delete the resource group after the namespaces are gone:

```bash
az group delete --name "$RESOURCE_GROUP" --yes --no-wait
```

For the Terraform path, run destroy with the same variable values you used for apply:

```bash
cd workloads/distributed-processing/apache-flink/infra/terraform
terraform destroy -auto-approve
```

## Implementation notes

- the Flink operator chart is pinned to `1.10.0`
- the sample job uses Flink `1.20.1` and the official image `flink:1.20.1`
- JobManager and TaskManager pods target `agentpool=flink` and tolerate `dedicated=flink:NoSchedule`
- the dedicated `flink` pool uses Managed OS disks to avoid regional allocation failures caused by AKS ephemeral OS disk defaults on `Standard_D8ds_v5`
- the operator autoscaler is enabled in the FlinkDeployment resource with a 70% target utilization
- checkpoint storage uses local filesystem for the starter; switch to ADLS Gen2 for production
- if you extend the design to ADLS Gen2, use workload identity and managed identity auth only
