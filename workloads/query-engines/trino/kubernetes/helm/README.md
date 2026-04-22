# Trino Helm assets

This folder contains the pinned Helm values for the Trino starter blueprint.

## Install sequence

```bash
export CHART_VERSION=1.42.1

kubectl apply -f workloads/query-engines/trino/kubernetes/manifests/namespace.yaml

helm repo add trino https://trinodb.github.io/charts/
helm repo update

helm upgrade --install trino trino/trino --version "$CHART_VERSION" --namespace trino --values workloads/query-engines/trino/kubernetes/helm/trino-values.yaml
```

## Notes

- the values are pinned to chart `1.42.1` and Trino `479`
- the checked-in catalog surface is `tpch` so the blueprint works without extra databases or secrets
- worker pods target the dedicated `trino` AKS pool and use an `emptyDir` spill path at `/var/trino/spill`
- the coordinator service stays `ClusterIP` by default so operator access uses port-forward or an internal-only path
- if your node pool labels or taints differ from the example, update the selectors and tolerations before installing

## Internal load balancer override

If you need VNet-shared access instead of port-forward, create a small override file like this and keep it environment-specific:

```yaml
service:
  type: LoadBalancer
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
```
