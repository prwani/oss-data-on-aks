# Apache Flink operator Helm assets

This folder holds the checked-in Helm values for the official Flink Kubernetes Operator installation.

- chart: `flink-kubernetes-operator/flink-kubernetes-operator`
- chart version: `1.10.0`
- release name assumed by the docs: `flink-kubernetes-operator`
- operator namespace assumed by the docs: `flink-operator`

## Install sequence

```bash
kubectl apply -f workloads/distributed-processing/apache-flink/kubernetes/manifests/namespace.yaml
kubectl apply -f workloads/distributed-processing/apache-flink/kubernetes/manifests/flink-serviceaccount-rbac.yaml

helm repo add flink-kubernetes-operator https://archive.apache.org/dist/flink/flink-kubernetes-operator-1.10.0/
helm repo update

helm upgrade --install flink-kubernetes-operator flink-kubernetes-operator/flink-kubernetes-operator \
  --version 1.10.0 \
  --namespace flink-operator \
  --create-namespace \
  --values workloads/distributed-processing/apache-flink/kubernetes/helm/operator-values.yaml

kubectl apply -f workloads/distributed-processing/apache-flink/kubernetes/manifests/flink-word-count.yaml
```

## Uninstall sequence

```bash
kubectl delete flinkdeployment flink-word-count -n flink --ignore-not-found=true
helm uninstall flink-kubernetes-operator -n flink-operator
kubectl delete namespace flink --wait=true --timeout=600s
kubectl delete namespace flink-operator --wait=true --timeout=600s
```

## Notes

- the values pin the operator pod to `agentpool=systempool`
- the operator watches only the `flink` namespace via `watchNamespaces`
- the chart's default job ServiceAccount and job RBAC are disabled because the checked-in manifests manage those explicitly
- the chart's admission webhook is disabled to avoid requiring cert-manager on a fresh cluster; re-enable with `webhook.create: true` once cert-manager is installed
- if you rename the system node pool, update the `nodeSelector` in `operator-values.yaml` before installing
- the operator includes the autoscaler module which monitors FlinkDeployment metrics and adjusts parallelism
- the sample `flink-word-count` job is bounded, so a quick transition from `RUNNING` to `FINISHED` is a successful outcome
