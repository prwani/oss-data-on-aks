# Apache Spark manifest assets

This folder keeps the runtime contract explicit.

- `namespace.yaml` creates the workload namespace used by Spark applications
- `spark-serviceaccount-rbac.yaml` creates the namespaced service account and RBAC the driver needs to create executors and related resources
- `spark-pi.yaml` submits a real sample `SparkApplication` that targets the dedicated `spark` node pool

## Apply order

Apply the namespace and RBAC before or alongside the operator install:

```bash
kubectl apply -f workloads/distributed-processing/apache-spark/kubernetes/manifests/namespace.yaml
kubectl apply -f workloads/distributed-processing/apache-spark/kubernetes/manifests/spark-serviceaccount-rbac.yaml
```

After the operator chart is installed and the CRDs exist, submit the sample application:

```bash
kubectl apply -f workloads/distributed-processing/apache-spark/kubernetes/manifests/spark-pi.yaml
```

The sample application keeps secondary resources for ten minutes and deletes the `SparkApplication` object after thirty minutes. That gives operators enough time to inspect driver and executor pods without turning the namespace into a graveyard.

No storage secret manifest is checked in because the starter job is self-contained. If you later add Azure Storage-backed data access, bind a workload identity-backed service account outside the checked-in default path and keep shared keys out of the design.
