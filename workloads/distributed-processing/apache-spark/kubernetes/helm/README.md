# Apache Spark operator Helm assets

This folder holds the checked-in Helm values for the official Spark operator installation.

- chart: `spark/spark-kubernetes-operator`
- chart version: `1.6.0`
- app version: `0.8.0`
- release name assumed by the docs: `spark-operator`
- operator namespace assumed by the docs: `spark-operator`

## Install sequence

```bash
kubectl apply -f workloads/distributed-processing/apache-spark/kubernetes/manifests/namespace.yaml
kubectl apply -f workloads/distributed-processing/apache-spark/kubernetes/manifests/spark-serviceaccount-rbac.yaml

helm repo add spark https://apache.github.io/spark-kubernetes-operator
helm repo update

helm upgrade --install spark-operator spark/spark-kubernetes-operator \
  --version 1.6.0 \
  --namespace spark-operator \
  --create-namespace \
  --values workloads/distributed-processing/apache-spark/kubernetes/helm/operator-values.yaml

kubectl apply -f workloads/distributed-processing/apache-spark/kubernetes/manifests/spark-pi.yaml
```

## Notes

- the values pin the operator pod to `agentpool=systempool`
- the operator watches only the `spark` namespace
- the chart's workload service account and RBAC objects are disabled because the checked-in manifests manage those explicitly
- if you rename the system node pool, update the `nodeSelector` in `operator-values.yaml` before installing
