# Running Apache Spark on AKS with the official Spark Kubernetes Operator and a dedicated job pool

**Publication target:** Microsoft TechCommunity > Azure > Linux and Open Source Blog

## Summary

Apache Spark is easy to demo on Kubernetes, but a reusable AKS blueprint needs more than a single `spark-submit` example. Spark jobs are short-lived, the driver creates executors at runtime, and shuffle plus spill can overwhelm generic nodes quickly.

This post walks through a starter blueprint for Apache Spark 4.1.1 on Azure Kubernetes Service (AKS) using the official `spark/spark-kubernetes-operator` chart 1.6.0, the operator app version 0.8.0, a dedicated `spark` user pool, explicit namespaced RBAC, and checked-in Terraform, Bicep, Helm, and operations guidance.

## Why Spark on AKS is not just another microservice

This is the key AKS design point: **Spark is not a long-running stateless service**.

A useful Spark environment on AKS includes:

- an operator that watches `SparkApplication` resources
- a driver pod that exists only for the lifetime of a job
- executor pods that scale up and disappear with the workload
- namespaced RBAC so the driver can create executors and related resources
- explicit local scratch space for shuffle and spill
- a job-oriented validation flow instead of a service-oriented readiness check

That is a very different shape from a normal web API that can be summarized as `Deployment + Service + external database`.

## What the repo now provides

The Spark workload in this repo is organized around five practical building blocks:

1. AKS AVM-based Terraform and Bicep wrappers under `workloads/distributed-processing/apache-spark/infra`
2. Spark architecture, portal, CLI, and operations guidance under `workloads/distributed-processing/apache-spark/docs`
3. operator Helm values and Spark manifests under `workloads/distributed-processing/apache-spark/kubernetes`
4. a starter node-pool layout with a dedicated `spark` AKS user pool
5. publish-ready blog assets under `blogs/apache-spark`

## Checked-in version contract

These are the repo-backed versions this walkthrough currently matches.

| Component | Checked-in version | Evidence in repo |
| --- | --- | --- |
| Operator chart | `spark/spark-kubernetes-operator` `1.6.0` | `workloads/distributed-processing/apache-spark/kubernetes/helm/README.md` |
| Operator app version | `0.8.0` | `workloads/distributed-processing/apache-spark/kubernetes/helm/README.md` |
| Sample Spark runtime | `4.1.1` with `apache/spark:4.1.1-scala` | `workloads/distributed-processing/apache-spark/kubernetes/manifests/spark-pi.yaml` |

## The target AKS pattern

The blueprint uses these opinions by default:

| Layer | Recommendation | Why |
| --- | --- | --- |
| AKS baseline | Shared AVM wrapper | Keeps cluster creation consistent across workloads |
| Operator control plane | `spark-operator` namespace on the system pool | Keeps reconciliation stable even when jobs are busy |
| Workload placement | Dedicated `spark` pool with 3 nodes | Isolates driver and executor pressure from AKS add-ons |
| Submission model | `SparkApplication` CRs | Matches the operator lifecycle instead of pretending Spark is a permanent service |
| Local scratch space | `emptyDir` at `/var/data/spark-local-dir` | Makes shuffle and spill explicit on AKS |
| Access path | `kubectl port-forward` to the driver UI while it runs | Keeps Spark internal by default |

The checked-in sample keeps dynamic allocation visible instead of hiding it: the job starts with two executors, can grow to three, pins the driver to `spark-pi-driver`, and mounts `emptyDir` scratch space with 20 GiB for the driver and 50 GiB for each executor.

## Prerequisites and environment contract

Before you start, make sure you have:

- an Azure subscription with quota for a dedicated `spark` node pool
- Azure CLI installed and logged in
- `kubectl` installed
- Helm 3.x installed
- Terraform 1.11+ if you want the Terraform path
- an AKS version compatible with the official Spark operator chart `1.6.0`

The repo-backed CLI path uses this environment contract:

```bash
export LOCATION=eastus
export RESOURCE_GROUP=rg-apache-spark-aks-dev
export CLUSTER_NAME=aks-apache-spark-dev
export SPARK_NAMESPACE=spark
export SPARK_OPERATOR_NAMESPACE=spark-operator
export SPARK_OPERATOR_RELEASE=spark-operator
export SPARK_HELM_VERSION=1.6.0
```

## Step 1: Deploy or align the AKS baseline

The repo keeps both IaC paths visible because different teams standardize differently.

### Bicep path

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

### Terraform path

```bash
cd workloads/distributed-processing/apache-spark/infra/terraform
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform plan
terraform apply
```

Both wrappers create `systempool` plus a dedicated `spark` user pool that gives driver and executor pods more CPU, memory, and node-local scratch headroom than a tiny shared pool would.

## Step 2: Create the workload namespace and RBAC

Connect to AKS and apply the namespace plus the explicitly managed service account and RBAC objects:

```bash
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME"

kubectl apply -f workloads/distributed-processing/apache-spark/kubernetes/manifests/namespace.yaml
kubectl apply -f workloads/distributed-processing/apache-spark/kubernetes/manifests/spark-serviceaccount-rbac.yaml
```

That split is deliberate. The chart does not create the workload service account or its RBAC because the checked-in manifests make the runtime permissions explicit.

## Step 3: Install the pinned Spark operator

```bash
helm repo add spark https://apache.github.io/spark-kubernetes-operator
helm repo update

helm upgrade --install "$SPARK_OPERATOR_RELEASE" spark/spark-kubernetes-operator \
  --version "$SPARK_HELM_VERSION" \
  --namespace "$SPARK_OPERATOR_NAMESPACE" \
  --create-namespace \
  --values workloads/distributed-processing/apache-spark/kubernetes/helm/operator-values.yaml
```

The checked-in values do two important things before any job is submitted:

- pin the operator pod to the **`systempool`** so reconciler health does not depend on batch pressure
- restrict the operator watch scope to the **`spark`** namespace so the workload boundary stays predictable

## Step 4: Submit the sample SparkApplication

The repo includes a real `spark-pi` `SparkApplication`, not a placeholder YAML stub:

```bash
kubectl apply -f workloads/distributed-processing/apache-spark/kubernetes/manifests/spark-pi.yaml
```

That manifest captures the starter runtime contract clearly:

- Spark image `apache/spark:4.1.1-scala`
- dynamic allocation from **2** to **3** executors
- driver and executor node selectors that target `agentpool=spark`
- tolerations for `dedicated=spark:NoSchedule`
- `spark.local.dir=/var/data/spark-local-dir` backed by `emptyDir`
- retained driver and executor resources for ten minutes after completion so logs and pod details remain inspectable

## Step 5: Validate the operator, driver, and UI

Validate the parts that matter for a Spark-on-AKS starter:

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

When you want to rerun the sample immediately, delete the application explicitly instead of waiting for the retained resources to age out:

```bash
kubectl delete sparkapplication spark-pi -n "$SPARK_NAMESPACE"
```

## The AKS-specific differences to keep in mind

If you are used to stateless application services, these are the Spark-on-AKS behaviors to internalize early:

1. **The operator is not the workload.** The real work happens in short-lived driver and executor pods in another namespace.
2. **Shuffle and spill are part of the platform contract.** Local storage pressure belongs in the first capacity conversation.
3. **The job lifecycle matters more than service exposure.** Spark health is about job completion, driver logs, and executor behavior, not a permanent VIP.
4. **RBAC is runtime plumbing.** The driver needs explicit rights to create executors and related resources.
5. **The system pool and the batch pool should not compete.** Reconciliation and execution behave better when they are separated.

## Azure integration notes

This starter intentionally does not invent a demo storage account or fake data lake credentials. If you extend the design later for ADLS Gen2, checkpoint output, or event logs, keep the repo rule intact: use workload identity and managed identity-based authentication instead of shared keys.

## Closing thought

Spark on AKS becomes much easier to reason about when the repo makes the real platform shape explicit: an operator on the system pool, namespaced RBAC, ephemeral driver and executor pods, a dedicated batch node pool, and visible shuffle plus spill behavior.

That is what this blueprint now provides. It is not pretending to be every possible Spark platform pattern, but it is a credible AKS starter that a platform team can evolve without throwing away the first implementation.
