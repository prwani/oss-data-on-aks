# Apache Spark portal deployment path

Use this guide when the team wants to validate the target AKS shape in the Azure portal before standardizing on automation.

## Outcome

You should end with:

- an AKS cluster created from the shared AVM-aligned pattern
- a dedicated `spark` user pool with three nodes
- a Spark operator release running in `spark-operator`
- a `spark` namespace with a namespaced service account and RBAC for driver pods
- a successful `spark-pi` run submitted as a `SparkApplication`

## Step 1: Review the blueprint assets

Before using the portal, review the checked-in target state:

- architecture: `docs/architecture.md`
- operator values: `kubernetes/helm/operator-values.yaml`
- workload manifests: `kubernetes/manifests/README.md`
- sample app: `kubernetes/manifests/spark-pi.yaml`

## Step 2: Create or align the resource group

Suggested names:

- resource group: `rg-apache-spark-aks-dev`
- cluster: `aks-apache-spark-dev`

Keeping those names aligned with the IaC files makes the later Terraform or Bicep path friction-free.

## Step 3: Create the AKS cluster in the portal

Mirror the AVM-oriented design decisions:

1. choose the target region
2. keep managed identity enabled
3. enable Azure Monitor if your platform standard expects it
4. keep the AKS API private if that matches your landing-zone policy
5. create the default system pool
6. add a user pool named `spark` with 3 Linux nodes

### Suggested `spark` pool settings

| Setting | Value |
| --- | --- |
| Node pool name | `spark` |
| Mode | `User` |
| Node count | `3` |
| VM size | `Standard_D8ds_v5` |
| OS disk | `128 GiB` |
| Taint | `dedicated=spark:NoSchedule` |

The checked-in SparkApplication manifest targets AKS's built-in `agentpool=spark` label. If you rename the pool, update the manifest selectors and tolerations before submitting jobs.

## Step 4: Connect to AKS and create the workload namespace

```bash
az aks get-credentials \
  --resource-group rg-apache-spark-aks-dev \
  --name aks-apache-spark-dev

kubectl apply -f workloads/distributed-processing/apache-spark/kubernetes/manifests/namespace.yaml
kubectl apply -f workloads/distributed-processing/apache-spark/kubernetes/manifests/spark-serviceaccount-rbac.yaml
```

## Step 5: Install the Spark operator

```bash
helm repo add spark https://apache.github.io/spark-kubernetes-operator
helm repo update

helm upgrade --install spark-operator spark/spark-kubernetes-operator \
  --version 1.6.0 \
  --namespace spark-operator \
  --create-namespace \
  --values workloads/distributed-processing/apache-spark/kubernetes/helm/operator-values.yaml
```

## Step 6: Submit the sample Spark job

```bash
kubectl apply -f workloads/distributed-processing/apache-spark/kubernetes/manifests/spark-pi.yaml
```

## Step 7: Validate the deployment

```bash
kubectl get pods -n spark-operator
kubectl get sparkapplications.spark.apache.org -n spark
kubectl describe sparkapplication spark-pi -n spark
kubectl get pods -n spark -o wide
kubectl logs pod/spark-pi-driver -n spark
```

For a live UI check while the driver is still running:

```bash
kubectl port-forward pod/spark-pi-driver 4040:4040 -n spark
```

## Portal-specific review points

- confirm the `spark` node pool has the expected VM size and taint
- confirm the operator pod is healthy in `spark-operator`
- confirm the driver and executors land only on `agentpool=spark` nodes
- confirm the workload reaches a healthy end state without `SchedulingFailure`
- confirm there is no public service that treats Spark like a permanent web endpoint

If you later add Azure Storage-backed data access, keep the same repo rule: use workload identity with managed identity auth and never shared keys.
