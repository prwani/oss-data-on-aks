# Apache Spark operations notes

Operational maturity for Spark on AKS is mostly about application lifecycle, node pressure, and explicit control over ephemeral resources.

## Daily and weekly signals

| Area | What to watch |
| --- | --- |
| Operator health | `spark-operator` pod restarts, reconciliation errors, and CRD availability |
| SparkApplication state | `RunningHealthy`, `SchedulingFailure`, `Failed`, or repeated retries |
| Spark pool health | `spark` nodes ready, schedulable, and not under maintenance pressure |
| Driver behavior | restarts, image pull failures, and driver exit codes |
| Executor fleet | executor churn, slow start, and pod placement drift |
| Local spill | node ephemeral storage pressure and growing shuffle directories |
| Data access | image drift, connector errors, and any future workload identity failures |

## Useful operational commands

```bash
kubectl get sparkapplications.spark.apache.org -n spark
kubectl describe sparkapplication spark-pi -n spark
kubectl get pods -n spark -o wide
kubectl logs pod/spark-pi-driver -n spark
kubectl get nodes -l agentpool=spark
kubectl get events -n spark --sort-by=.lastTimestamp | tail -n 20
```

## Scaling guidance

Prefer these steps over ad hoc changes:

1. increase the `spark` pool size or VM SKU when executor scheduling and spill pressure are the main bottlenecks
2. preserve at least three schedulable `spark` nodes if you later turn on the autoscaler so the driver and starter executors can place cleanly
3. separate especially noisy teams or job classes into another namespace and node pool before overloading the same `spark` pool
4. revisit executor memory, dynamic allocation bounds, and local spill size together rather than changing one knob in isolation

## Upgrade guidance

- pin and validate the Spark operator chart version and Spark image tag together
- re-run `spark-pi` after AKS node image upgrades, Spark image updates, or chart upgrades
- confirm the CRD version shipped by the chart before upgrading the operator in place
- keep the operator on the system pool so control-plane reconciliation stays separate from job pressure

## Security and platform guidance

- keep the workload namespace and operator namespace separate
- do not commit secrets or fake storage credentials into the repo
- expose the Spark UI only through a controlled internal path such as `kubectl port-forward`
- use workload identity plus managed identity auth for Azure Storage-backed datasets or event logs

## Recommended runbooks

- `SchedulingFailure` because the `spark` pool is full or the taint/selector contract drifted
- node ephemeral storage pressure from large shuffle or spill workloads
- stuck SparkApplication cleanup before resubmission
- onboarding a workload identity-backed service account for ADLS or event logs
- validation after an AKS node image upgrade
