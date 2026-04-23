# Apache Flink architecture notes

Flink on AKS should be treated as a stateful distributed stream and batch processing runtime with an operator control plane, long-running or ephemeral JobManager and TaskManager pods, and explicit checkpoint and autoscaling behavior.

## Why this workload needs a different AKS design

Flink on AKS is not a typical stateless microservice:

- the **FlinkDeployment custom resource** is the durable control object, not a long-lived `Deployment` with fixed replicas
- the **JobManager** manages execution graphs, triggers checkpoints, and coordinates recovery
- **TaskManager pods are compute slots** whose count changes with job parallelism, so scheduling pressure and autoscaling behavior matter more than sticky service endpoints
- **checkpoints and savepoints** are durability contracts, and their storage location determines whether recovery and upgrades actually work
- **high availability** requires leader election and a durable storage directory, adding infrastructure dependencies beyond plain pod scheduling
- operational success depends on **job lifecycle visibility, checkpoint health, backpressure monitoring, and autoscaler tuning**, not only pod count

## Recommended reference architecture

```text
+------------------------------------------------------------------------+
| AKS cluster                                                            |
|                                                                        |
|  systempool                                                            |
|   - AKS add-ons                                                        |
|   - flink-kubernetes-operator deployment (chart 1.10.0)                |
|                                                                        |
|  flink user pool (3 x Standard_D8ds_v5, taint dedicated=flink)         |
|   - namespace flink                                                    |
|   - serviceaccount flink + namespaced RBAC                             |
|   - FlinkDeployment resources (Application mode)                       |
|   - JobManager pod (1 replica, 2 GiB, 1 CPU)                          |
|   - TaskManager pods (2-6 pods via operator autoscaler)                |
|   - emptyDir for local working directories                             |
|   - Kubernetes-native HA via ConfigMap leader election                 |
|                                                                        |
|  AKS cluster autoscaler (post-deployment)                              |
|   - enabled on flink pool: min 3, max 10 nodes                        |
|   - backs the operator autoscaler with node-level elasticity           |
|                                                                        |
|  Operator workflow                                                     |
|   - kubectl get flinkdeployments -n flink                              |
|   - kubectl logs deploy/flink-word-count -n flink                      |
|   - kubectl port-forward svc/flink-word-count-rest 8081:8081           |
+------------------------------------------------------------------------+
```

## Design decisions

| Area | Recommendation | Notes |
| --- | --- | --- |
| Cluster baseline | Use AKS AVM wrappers | Keeps Flink aligned with the rest of the repo |
| Operator install | Official Flink Kubernetes Operator chart `1.10.0` in `flink-operator` | Keeps the control loop pinned and explicit |
| Workload placement | Dedicated `flink` pool with 3 nodes | Isolates streaming and batch jobs from AKS system components |
| Deployment model | `FlinkDeployment` in Application mode | Each job gets its own isolated Flink cluster with dedicated JobManager |
| High availability | Kubernetes-native HA with ConfigMap leader election | Avoids ZooKeeper dependency; requires durable `high-availability.storageDir` for production |
| Checkpoint storage | Local filesystem for starter (not durable); ADLS Gen2 for production | The starter validates operator health but does not survive pod or node loss |
| State backend | HashMaps for starter; RocksDB for production stateful jobs | RocksDB supports incremental checkpoints and large state |
| Job autoscaling | Flink operator autoscaler enabled in FlinkDeployment | Adjusts parallelism and TaskManager count based on backpressure |
| Node autoscaling | AKS cluster autoscaler on flink pool (post-deployment) | Adds nodes when operator-requested TaskManagers cannot schedule |
| Azure data access | Add later with workload identity | Keeps Azure Storage shared keys out of the design |

## AKS-specific guidance

### 1. JobManager and TaskManager have different lifecycle expectations

The JobManager is the coordination brain of a Flink job:

- it persists for the lifetime of the FlinkDeployment
- it manages the execution graph, triggers checkpoints, and handles failover
- only one active JobManager exists per FlinkDeployment (standby replicas for HA are optional)

TaskManagers are the execution workers:

- the operator autoscaler may add or remove TaskManager pods based on backpressure
- each TaskManager provides a fixed number of task slots (configured via `taskmanager.numberOfTaskSlots`)
- TaskManager loss triggers task redistribution from the last successful checkpoint

### 2. The dedicated `flink` node pool is for execution isolation

The checked-in IaC provisions:

- `systempool` for AKS add-ons and the lightweight Flink operator pod
- one user pool named `flink`
- three `Standard_D8ds_v5` nodes in that pool
- the taint `dedicated=flink:NoSchedule`

The FlinkDeployment manifest pins JobManager and TaskManager pods to `agentpool=flink` and adds matching tolerations. This keeps Flink execution away from the system pool.

### 3. Two-layer autoscaling

This blueprint configures autoscaling at two independent layers:

**Layer 1: Flink operator autoscaler (job-level)**

The Flink Kubernetes Operator includes a built-in autoscaler that monitors:

- source backpressure and busy time per vertex
- target utilization thresholds (default 70%)
- stabilization windows to avoid flapping

When backpressure exceeds the target, the operator increases job parallelism and adds TaskManager pods. When utilization drops, it scales down after a stabilization period. This is configured in the `FlinkDeployment` resource via `flinkConfiguration` properties:

```yaml
flinkConfiguration:
  job.autoscaler.enabled: "true"
  job.autoscaler.stabilization.interval: "5m"
  job.autoscaler.metrics.window: "10m"
  job.autoscaler.target.utilization: "0.7"
  job.autoscaler.target.utilization.boundary: "0.1"
  job.autoscaler.scale-down.max-factor: "0.6"
  job.autoscaler.scale-up.max-factor: "100000"
```

**Layer 2: AKS cluster autoscaler (node-level)**

When the operator requests more TaskManager pods than the current nodes can schedule, the pods go Pending. The AKS cluster autoscaler detects pending pods and adds nodes to the `flink` pool. Enable this post-deployment:

```bash
az aks nodepool update \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --name flink \
  --enable-cluster-autoscaler \
  --min-count 3 \
  --max-count 10
```

This two-layer design keeps job-level scaling decisions with the Flink operator (which understands backpressure) and node-level scaling decisions with AKS (which understands VM provisioning).

### 4. High availability uses Kubernetes-native leader election

The starter configures Kubernetes-native HA:

```yaml
high-availability.type: kubernetes
high-availability.storageDir: file:///flink-data/ha
```

This uses Kubernetes ConfigMaps for leader election and the filesystem (backed by `emptyDir` in the starter) for HA metadata. The starter configuration validates operator health and pod placement but is **not durable across pod or node loss**. For production deployments with durable HA storage, replace the filesystem path with an ADLS Gen2 URI:

```yaml
high-availability.storageDir: abfss://flink-data@<STORAGE_ACCOUNT>.dfs.core.windows.net/ha
```

### 5. Checkpointing determines recovery posture

The starter configures periodic checkpoints:

```yaml
execution.checkpointing.interval: "60000"
execution.checkpointing.min-pause: "30000"
state.checkpoints.dir: file:///flink-data/checkpoints
state.savepoints.dir: file:///flink-data/savepoints
```

For the starter, these use the local filesystem via `emptyDir`. This validates operator health and pod placement but is **not durable across pod or node loss**. For production:

1. enable AKS workload identity in the shared platform baseline
2. bind the Flink service account to a user-assigned managed identity
3. grant `Storage Blob Data Contributor` on the target ADLS Gen2 container
4. update the FlinkDeployment to use ADLS Gen2 URIs:

```yaml
state.checkpoints.dir: abfss://flink-data@<STORAGE_ACCOUNT>.dfs.core.windows.net/checkpoints
state.savepoints.dir: abfss://flink-data@<STORAGE_ACCOUNT>.dfs.core.windows.net/savepoints
high-availability.storageDir: abfss://flink-data@<STORAGE_ACCOUNT>.dfs.core.windows.net/ha
```

5. add the Azure filesystem plugin to the Flink image:

```yaml
flinkConfiguration:
  fs.azure.account.auth.type: MANAGED_IDENTITY
  fs.azure.account.oauth2.client.id: "<MANAGED_IDENTITY_CLIENT_ID>"
```

Do not reintroduce storage account keys or shared-key auth to "simplify" the deployment.

### 6. The operator and the jobs have different responsibilities

The checked-in Helm values pin the operator deployment to `agentpool=systempool`, while Flink jobs use the `flink` pool. That separation keeps the operator controller steady even when the Flink pool is busy with autoscaler-driven pod churn.

## Capacity planning starter values

| Component | Starter shape | Purpose |
| --- | --- | --- |
| System pool | 1 x `Standard_D2s_v5` | AKS add-ons and the Flink operator |
| Flink pool | 3 x `Standard_D8ds_v5` | JobManager and TaskManager scheduling |
| Operator | 500m-1 CPU / 1 GiB memory | Lightweight control plane |
| JobManager | 2 GiB memory / 1 CPU | Job coordination, checkpoint management, Web UI |
| TaskManagers | 2-6 pods x 4 GiB memory / 2 CPUs / 2 task slots | Dataflow execution |
| Local working dirs | 10 GiB `emptyDir` per pod | Checkpoint staging, HA metadata, local working state |
| AKS cluster autoscaler | min 3 / max 10 nodes (post-deployment) | Node-level elasticity for operator-driven TaskManager scaling |

These are starter values for a reusable blueprint, not a final production sizing target. Increase node size, TaskManager memory, task slots, or pool bounds based on state size, checkpoint volume, and the number of concurrent Flink jobs your workloads require.
