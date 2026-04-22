# Apache Spark `az` CLI deployment path

Use this path when you want the Azure resource shape, operator install, and sample Spark job captured as code.

## Prerequisites

- Azure CLI
- `kubectl`
- Helm 3.x
- Terraform 1.11+ if you want the Terraform path
- an AKS version compatible with the official Spark operator chart `1.6.0`

## Environment variables

```bash
export LOCATION=eastus
export RESOURCE_GROUP=rg-apache-spark-aks-dev
export CLUSTER_NAME=aks-apache-spark-dev
export SPARK_NAMESPACE=spark
export SPARK_OPERATOR_NAMESPACE=spark-operator
export SPARK_OPERATOR_RELEASE=spark-operator
export SPARK_HELM_VERSION=1.6.0
```

## Option A: Bicep wrapper

```bash
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file workloads/distributed-processing/apache-spark/infra/bicep/main.bicep \
  --parameters \
      clusterName="$CLUSTER_NAME" \
      location="$LOCATION"
```

This wrapper creates the shared AKS baseline plus the dedicated `spark` user pool defined for the workload.

## Option B: Terraform wrapper

```bash
cd workloads/distributed-processing/apache-spark/infra/terraform
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
kubectl apply -f workloads/distributed-processing/apache-spark/kubernetes/manifests/namespace.yaml
kubectl apply -f workloads/distributed-processing/apache-spark/kubernetes/manifests/spark-serviceaccount-rbac.yaml
```

## Install the Spark operator

```bash
helm repo add spark https://apache.github.io/spark-kubernetes-operator
helm repo update

helm upgrade --install "$SPARK_OPERATOR_RELEASE" spark/spark-kubernetes-operator \
  --version "$SPARK_HELM_VERSION" \
  --namespace "$SPARK_OPERATOR_NAMESPACE" \
  --create-namespace \
  --values workloads/distributed-processing/apache-spark/kubernetes/helm/operator-values.yaml
```

The checked-in values pin the operator to the `systempool` node pool and tell it to watch only the `spark` namespace.

## Submit the sample SparkApplication

```bash
kubectl apply -f workloads/distributed-processing/apache-spark/kubernetes/manifests/spark-pi.yaml
```

## Validate the deployment

```bash
kubectl get pods -n "$SPARK_OPERATOR_NAMESPACE"
kubectl get sparkapplications.spark.apache.org -n "$SPARK_NAMESPACE"
kubectl describe sparkapplication spark-pi -n "$SPARK_NAMESPACE"
kubectl get pods -n "$SPARK_NAMESPACE" -o wide
kubectl logs pod/spark-pi-driver -n "$SPARK_NAMESPACE"
```

For a live Spark UI check while the driver is still running:

```bash
kubectl port-forward pod/spark-pi-driver 4040:4040 -n "$SPARK_NAMESPACE"
```

## Cleanup and rerun

The sample retains driver and executor resources for ten minutes after completion so logs and pod details remain inspectable. Delete the application explicitly when you want to rerun immediately:

```bash
kubectl delete sparkapplication spark-pi -n "$SPARK_NAMESPACE"
```

## Implementation notes

- the Spark operator chart is pinned to `1.6.0`
- the sample job pins Spark to `4.1.1` and the official image `apache/spark:4.1.1-scala`
- driver and executor pods target `agentpool=spark` and tolerate `dedicated=spark:NoSchedule`
- `spark.local.dir` is backed by `emptyDir`, so node ephemeral storage is part of the runtime contract
- if you extend the design to ADLS or event logs, use workload identity and managed identity auth only
