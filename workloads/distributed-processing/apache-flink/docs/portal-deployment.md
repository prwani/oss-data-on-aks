# Apache Flink portal deployment path

Use this guide when the team wants to validate the target AKS shape in the Azure portal before standardizing on automation.

## Outcome

You should end with:

- an AKS cluster created from the shared AVM-aligned pattern
- a dedicated `flink` user pool with three nodes
- a Flink Kubernetes Operator release running in `flink-operator`
- a `flink` namespace with a namespaced service account and RBAC for Flink jobs
- a successful `flink-word-count` FlinkDeployment with the operator autoscaler enabled
- the AKS cluster autoscaler enabled on the `flink` pool for node-level elasticity

## Step 1: Review the blueprint assets

Before using the portal, review the checked-in target state:

- architecture: `docs/architecture.md`
- operator values: `kubernetes/helm/operator-values.yaml`
- workload manifests: `kubernetes/manifests/README.md`
- sample job: `kubernetes/manifests/flink-word-count.yaml`

## Step 2: Create or align the resource group

Suggested names:

- resource group: `rg-apache-flink-aks-dev`
- cluster: `aks-apache-flink-dev`

Keeping those names aligned with the IaC files makes the later Terraform or Bicep path friction-free.

## Step 3: Create the AKS cluster in the portal

Mirror the AVM-oriented design decisions:

1. choose the target region
2. keep managed identity enabled
3. enable Azure Monitor if your platform standard expects it
4. keep the AKS API private if that matches your landing-zone policy
5. create the default system pool
6. add a user pool named `flink` with 3 Linux nodes

### Suggested `flink` pool settings

| Setting | Value |
| --- | --- |
| Node pool name | `flink` |
| Mode | `User` |
| Node count | `3` |
| VM size | `Standard_D8ds_v5` |
| OS disk | `128 GiB` |
| OS disk type | `Managed` |
| Taint | `dedicated=flink:NoSchedule` |
| Enable autoscaling | `Yes` |
| Minimum node count | `3` |
| Maximum node count | `10` |

The portal path enables the AKS cluster autoscaler during pool creation. The `az` CLI path enables it as a post-deployment step. Both produce the same end state.

Keep the `flink` pool on **Managed** OS disks. On `Standard_D8ds_v5`, letting AKS default to ephemeral OS disks can trigger overconstrained allocation failures in `swedencentral`.

The checked-in FlinkDeployment manifest targets AKS's built-in `agentpool=flink` label. If you rename the pool, update the manifest selectors and tolerations before submitting jobs.

## Step 4: Connect to AKS and create the workload namespace

```bash
az aks get-credentials \
  --resource-group rg-apache-flink-aks-dev \
  --name aks-apache-flink-dev

kubectl apply -f workloads/distributed-processing/apache-flink/kubernetes/manifests/namespace.yaml
kubectl apply -f workloads/distributed-processing/apache-flink/kubernetes/manifests/flink-serviceaccount-rbac.yaml
```

## Step 5: Install the Flink Kubernetes Operator

```bash
helm repo add flink-kubernetes-operator https://archive.apache.org/dist/flink/flink-kubernetes-operator-1.10.0/
helm repo update

helm upgrade --install flink-kubernetes-operator flink-kubernetes-operator/flink-kubernetes-operator \
  --version 1.10.0 \
  --namespace flink-operator \
  --create-namespace \
  --values workloads/distributed-processing/apache-flink/kubernetes/helm/operator-values.yaml
```

## Step 6: Submit the sample Flink job

The sample runs the bundled WordCount jar as a bounded smoke test. It validates operator health and pod placement but finishes quickly.

```bash
kubectl apply -f workloads/distributed-processing/apache-flink/kubernetes/manifests/flink-word-count.yaml
```

## Step 7: Validate the deployment

```bash
kubectl get pods -n flink-operator
kubectl get flinkdeployments -n flink
kubectl describe flinkdeployment flink-word-count -n flink
kubectl get pods -n flink -o wide
kubectl logs deploy/flink-word-count -n flink -c flink-main-container
```

For a live Flink Web UI check while the job is still running (the sample is bounded and finishes quickly):

```bash
kubectl port-forward svc/flink-word-count-rest 8081:8081 -n flink
```

Because the sample WordCount job is bounded, a fast transition from `RUNNING` to `FINISHED` is still a successful validation outcome.

## Step 8: Tear down cleanly

If you are deleting the whole environment after validation, remove the FlinkDeployment and operator first:

```bash
kubectl delete flinkdeployment flink-word-count -n flink --ignore-not-found=true
helm uninstall flink-kubernetes-operator -n flink-operator
kubectl delete namespace flink --wait=true --timeout=600s
kubectl delete namespace flink-operator --wait=true --timeout=600s
```

After those namespaces are gone, delete the AKS cluster or the whole resource group from the portal.

## Portal-specific review points

- confirm the `flink` node pool has the expected VM size, taint, and autoscaling settings
- confirm the operator pod is healthy in `flink-operator`
- confirm the JobManager and TaskManagers land only on `agentpool=flink` nodes
- confirm the FlinkDeployment reaches `RUNNING` and, for the bounded sample, may then transition cleanly to `FINISHED`
- confirm there is no public service that treats Flink like a permanent web endpoint
- confirm the autoscaler column in the portal shows the `flink` pool as autoscale-enabled with min 3, max 10

If you later add ADLS Gen2-backed checkpoint storage, keep the same repo rule: use workload identity with managed identity auth and never shared keys.
