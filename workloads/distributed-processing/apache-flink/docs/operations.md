# Apache Flink operations notes

Operational maturity for Flink on AKS covers job lifecycle, checkpoint health, autoscaler behavior, and explicit control over TaskManager scaling.

## Daily and weekly signals

| Area | What to watch |
| --- | --- |
| Operator health | `flink-kubernetes-operator` pod restarts, reconciliation errors, and CRD availability |
| FlinkDeployment state | `RUNNING`, `FAILED`, `SUSPENDED`, or repeated restarts |
| JobManager health | restarts, image pull failures, and checkpoint trigger failures |
| TaskManager fleet | TaskManager availability, pod churn from autoscaler, and scheduling failures |
| Checkpoint health | checkpoint duration, size growth, failed checkpoints, and alignment time |
| Autoscaler activity | parallelism changes, scale-up/scale-down events, and stabilization window behavior |
| Node pool health | `flink` nodes ready, schedulable, cluster autoscaler activity |
| Backpressure | per-vertex busy time and backpressure ratio in the Flink Web UI |
| Data access | image drift, connector errors, and any future workload identity failures |

## Useful operational commands

```bash
# Operator and CRD health
kubectl get pods -n flink-operator
kubectl get crd flinkdeployments.flink.apache.org

# FlinkDeployment status
kubectl get flinkdeployments -n flink
kubectl describe flinkdeployment flink-word-count -n flink

# Pod placement and health
kubectl get pods -n flink -o wide
kubectl get events -n flink --sort-by=.lastTimestamp | tail -n 20

# JobManager logs
kubectl logs deploy/flink-word-count -n flink -c flink-main-container

# Flink Web UI (while the job is running)
kubectl port-forward svc/flink-word-count-rest 8081:8081 -n flink

# Node pool status
kubectl get nodes -l agentpool=flink

# Autoscaler events (look for scaling decisions in operator logs)
kubectl logs deploy/flink-kubernetes-operator -n flink-operator | grep -i autoscaler

# Checkpoint status via Flink REST API (while port-forward is active)
curl http://localhost:8081/jobs
curl http://localhost:8081/jobs/<JOB_ID>/checkpoints
```

## Autoscaler tuning guidance

The Flink operator autoscaler monitors source backpressure and TaskManager busy time to adjust parallelism. Key tuning parameters in the `FlinkDeployment` resource:

| Parameter | Starter value | Purpose |
| --- | --- | --- |
| `job.autoscaler.enabled` | `true` | Enables automatic parallelism adjustment |
| `job.autoscaler.stabilization.interval` | `5m` | Time to wait after a scaling event before scaling again |
| `job.autoscaler.metrics.window` | `10m` | Window of metrics to consider for scaling decisions |
| `job.autoscaler.target.utilization` | `0.7` | Target busy time ratio (70%) |
| `job.autoscaler.target.utilization.boundary` | `0.1` | Scale down when utilization drops below this margin from target |
| `job.autoscaler.scale-down.max-factor` | `0.6` | Maximum fraction to scale down in one step |
| `job.autoscaler.scale-up.max-factor` | `100000` | Maximum factor to scale up in one step |

### Common autoscaler adjustments

- **Frequent flapping**: increase `stabilization.interval` to 10-15 minutes
- **Slow reaction to traffic spikes**: decrease `stabilization.interval` and `metrics.window`
- **Too aggressive scale-down**: decrease `scale-down.max-factor` or increase `target.utilization.boundary`
- **Scale-up not happening**: check that the AKS cluster autoscaler is enabled on the `flink` pool so new nodes can be provisioned
- **Pending TaskManagers**: the AKS cluster autoscaler may need time to provision nodes; check `kubectl get events -n flink` for scheduling failures

### AKS cluster autoscaler for the flink pool

Enable the AKS cluster autoscaler after deployment to support node-level elasticity:

```bash
az aks nodepool update \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --name flink \
  --enable-cluster-autoscaler \
  --min-count 3 \
  --max-count 10
```

Monitor cluster autoscaler activity:

```bash
kubectl get events -n kube-system | grep cluster-autoscaler
kubectl get nodes -l agentpool=flink -o wide
```

## Scaling guidance

Prefer these steps over ad hoc changes:

1. let the Flink operator autoscaler handle parallelism and TaskManager count within the current node capacity
2. enable the AKS cluster autoscaler on the `flink` pool when you need elastic node provisioning
3. increase the `flink` pool VM SKU or max node count when the autoscaler ceiling is not sufficient
4. preserve at least three schedulable `flink` nodes as the autoscaler minimum so the JobManager and starter TaskManagers can place cleanly
5. increase `taskmanager.numberOfTaskSlots` before adding more TaskManager pods if the workload is CPU-light but parallelism-heavy
6. separate especially noisy jobs or tenants into another namespace and node pool before overloading the same `flink` pool
7. revisit TaskManager memory, task slots, checkpoint interval, and autoscaler bounds together rather than changing one knob in isolation

## Upgrade guidance

- pin and validate the Flink operator chart version and Flink image tag together
- for stateful jobs with durable checkpoint storage, take a savepoint before upgrading by patching the FlinkDeployment spec:

```bash
kubectl patch flinkdeployment flink-word-count -n flink --type merge \
  -p '{"spec":{"job":{"savepointTriggerNonce": '$(date +%s)' }}}'
```

> **Note:** savepoints are not meaningful with the checked-in starter configuration because it uses `upgradeMode: stateless` and local `emptyDir` storage. Configure ADLS Gen2-backed checkpoint/savepoint directories and set `upgradeMode: savepoint` before relying on savepoint-based upgrades.

- re-run a sample job after AKS node image upgrades, Flink image updates, or operator chart upgrades
- confirm the CRD version shipped by the chart before upgrading the operator in place
- keep the operator on the system pool so control-plane reconciliation stays separate from job pressure
- when upgrading from savepoint, update the `FlinkDeployment` spec with the savepoint path and set `upgradeMode: savepoint`

## Backup and recovery

- checkpoints are automatic and periodic; the starter uses local filesystem (not durable across pod loss)
- for production recovery, configure checkpoint and savepoint directories on ADLS Gen2
- savepoints are manual and should be triggered before planned upgrades or maintenance
- to restore from a savepoint, update the FlinkDeployment with `initialSavepointPath`
- document the savepoint location convention for your team so recovery is not a guessing game

## Security and platform guidance

- keep the workload namespace and operator namespace separate
- do not commit secrets or fake storage credentials into the repo
- expose the Flink Web UI only through a controlled internal path such as `kubectl port-forward`
- use workload identity plus managed identity auth for ADLS Gen2-backed checkpoints or data sources
- review RBAC: the checked-in role grants only the permissions the operator needs for pod, service, configmap, and deployment management

## Recommended runbooks

- `SchedulingFailure` because the `flink` pool is full or the taint/selector contract drifted
- checkpoint failures due to state size growth or storage pressure
- autoscaler flapping from unstable source throughput patterns
- TaskManager OOM from undersized memory or large keyed state
- stuck FlinkDeployment in `SUSPENDED` or `FAILED` state
- savepoint-based recovery after a planned upgrade
- onboarding a workload identity-backed service account for ADLS Gen2
- validation after an AKS node image upgrade
- AKS cluster autoscaler not adding nodes (check limits, quotas, and pool max-count)
