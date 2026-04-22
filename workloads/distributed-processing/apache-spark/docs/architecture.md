# Apache Spark architecture notes

Spark on AKS should be treated as a batch-oriented distributed runtime with an operator control plane, short-lived driver and executor pods, and explicit local-storage behavior.

## Why this workload needs a different AKS design

Spark on AKS is not a long-running microservice:

- the **SparkApplication custom resource** is the durable control object, not a long-lived `Deployment`
- the **driver pod is ephemeral** and orchestrates executor creation for one job run
- **executor pods are disposable compute slots**, so queueing, node pressure, and cleanup behavior matter more than sticky service endpoints
- **shuffle and spill** hit node-local storage, so small generic nodes become a bottleneck quickly
- operational success depends on **job lifecycle visibility, RBAC, and node-pool isolation**, not only pod count

## Recommended reference architecture

```text
+--------------------------------------------------------------------+
| AKS cluster                                                        |
|                                                                    |
|  systempool                                                        |
|   - AKS add-ons                                                    |
|   - spark-operator deployment (chart 1.6.0)                        |
|                                                                    |
|  spark user pool (3 x Standard_D8ds_v5, taint dedicated=spark)     |
|   - namespace spark                                                |
|   - serviceaccount spark + namespaced RBAC                         |
|   - SparkApplication resources                                     |
|   - ephemeral driver pod                                           |
|   - 2-3 executor pods via dynamic allocation                       |
|   - emptyDir local dirs at /var/data/spark-local-dir               |
|                                                                    |
|  Operator workflow                                                 |
|   - kubectl get sparkapplications -n spark                         |
|   - kubectl logs spark-pi-driver -n spark                          |
|   - kubectl port-forward pod/spark-pi-driver 4040:4040             |
+--------------------------------------------------------------------+
```

## Design decisions

| Area | Recommendation | Notes |
| --- | --- | --- |
| Cluster baseline | Use AKS AVM wrappers | Keeps Spark aligned with the rest of the repo |
| Operator install | Official Spark operator chart `1.6.0` in `spark-operator` | Keeps the control loop pinned and explicit |
| Workload placement | Dedicated `spark` pool with 3 nodes | Isolates batch jobs from AKS system components |
| Submission model | `SparkApplication` resources | Matches the operator's status and cleanup model |
| Job scratch space | `emptyDir` mounted to `/var/data/spark-local-dir` | Makes shuffle and spill visible from day one |
| Cleanup posture | Retain secondary resources for 10 minutes, delete the CR after 30 minutes | Gives operators time to inspect driver and executor artifacts without leaving clutter behind |
| Azure data access | Add later with workload identity | Keeps Azure Storage shared keys out of the design |

## AKS-specific guidance

### 1. Driver and executor pods are intentionally ephemeral

The checked-in `spark-pi.yaml` models the job the way Spark runs on Kubernetes in practice:

- one driver pod named `spark-pi-driver`
- dynamic executor scale-out up to three executors
- secondary resources retained for ten minutes after completion through `resourceRetainDurationMillis`
- the `SparkApplication` custom resource garbage-collected after thirty minutes through `ttlAfterStopMillis`

That lifecycle is the opposite of a typical stateless service that aims to keep the same deployment running indefinitely.

### 2. The dedicated `spark` node pool is for execution isolation

The checked-in IaC provisions:

- `systempool` for AKS add-ons and the lightweight Spark operator pod
- one user pool named `spark`
- three `Standard_D8ds_v5` nodes in that pool
- the taint `dedicated=spark:NoSchedule`

The SparkApplication manifest pins driver and executor pods to `agentpool=spark` and adds matching tolerations. This keeps short-lived Spark execution away from the system pool and gives the job access to a larger local temp disk footprint.

### 3. Shuffle and spill are first-class AKS concerns

The starter sample sets `spark.local.dir=/var/data/spark-local-dir` and mounts `emptyDir` volumes for both the driver and executors. That is a deliberate AKS design choice:

- shuffle files do not belong on tiny system nodes
- spill pressure shows up as **node ephemeral storage pressure**, not as a database alert
- right-sizing the `spark` pool means balancing CPU, memory, and local temp storage together

For this reason, the starter pool uses a `D8ds_v5` SKU instead of a smaller generic VM size.

### 4. The operator and the jobs have different responsibilities

The checked-in Helm values pin the operator deployment to `agentpool=systempool`, while Spark jobs use the `spark` pool. That separation keeps the controller steady even when the Spark pool is busy, while still making driver and executor placement explicit.

### 5. Azure Storage must use managed identity-based auth

This starter does not create an Azure Storage account because the first runnable workflow is self-contained around `spark-pi`. When you extend the design to ADLS Gen2, event logs, or checkpoint output:

1. enable AKS workload identity in the shared platform baseline
2. bind a Spark-specific service account to a user-assigned managed identity
3. grant only the required Azure RBAC role on the target container or filesystem
4. use Spark Hadoop settings such as:

```text
spark.hadoop.fs.azure.account.auth.type.${STORAGE_ACCOUNT}.dfs.core.windows.net=ManagedIdentity
spark.hadoop.fs.azure.account.oauth2.client.id.${STORAGE_ACCOUNT}.dfs.core.windows.net=${MANAGED_IDENTITY_CLIENT_ID}
```

Do not reintroduce storage account keys or shared-key auth to “simplify” the deployment.

## Capacity planning starter values

| Component | Starter shape | Purpose |
| --- | --- | --- |
| System pool | 1 x `Standard_D2s_v5` | AKS add-ons and the Spark operator |
| Spark pool | 3 x `Standard_D8ds_v5` | Driver and executor scheduling |
| Operator | 500m-1 CPU / 1 GiB memory | Lightweight control plane |
| Driver | 1.5 GiB memory | Job coordination and Spark UI |
| Executors | up to 3 x 1 core / 2 GiB | Sample batch execution |
| Local dirs | driver 20 GiB / executor 50 GiB `emptyDir` | Shuffle and spill headroom |

These are starter values for a reusable blueprint, not a final production sizing target. Increase node size, executor memory, or pool count based on shuffle volume, job concurrency, and the amount of local spill your workloads generate.
