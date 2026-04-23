# Apache Flink manifest assets

This folder keeps the runtime contract explicit.

- `namespace.yaml` creates the workload namespace used by Flink jobs
- `flink-serviceaccount-rbac.yaml` creates the namespaced service account and RBAC the Flink operator needs to manage JobManager and TaskManager pods
- `flink-word-count.yaml` submits a real sample `FlinkDeployment` that targets the dedicated `flink` node pool with the operator autoscaler enabled

## Apply order

Apply the namespace and RBAC before or alongside the operator install:

```bash
kubectl apply -f workloads/distributed-processing/apache-flink/kubernetes/manifests/namespace.yaml
kubectl apply -f workloads/distributed-processing/apache-flink/kubernetes/manifests/flink-serviceaccount-rbac.yaml
```

After the operator chart is installed and the CRDs exist, submit the sample FlinkDeployment:

```bash
kubectl apply -f workloads/distributed-processing/apache-flink/kubernetes/manifests/flink-word-count.yaml
```

The sample FlinkDeployment runs a bounded WordCount job as a smoke test with the operator autoscaler configuration enabled. It validates operator health, CRD reconciliation, and pod placement on the dedicated `flink` pool. Replace the bundled WordCount jar with an unbounded source connector to validate long-running autoscaler behavior.

No storage secret manifest is checked in because the starter job is self-contained. If you later add ADLS Gen2-backed checkpoints, bind a workload identity-backed service account outside the checked-in default path and keep shared keys out of the design.
