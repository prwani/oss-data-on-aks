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
- the checked-in workload validates `tpcds` so Trino can generate benchmark rows without extra source data; the upstream chart may also render its default `tpch` catalog
- use `trino-iceberg-adls-values.example.yaml` as an environment-specific override after the Iceberg REST catalog and ADLS Gen2 foundation are ready
- worker pods target the dedicated `trino` AKS pool and use an `emptyDir` spill path at `/var/trino/spill`
- the coordinator service stays `ClusterIP` by default so operator access uses port-forward or an internal-only path
- if your node pool labels or taints differ from the example, update the selectors and tolerations before installing
- ADLS Gen2 access must use workload identity or managed identity-based authentication; do not add storage keys to Helm values

## Iceberg and ADLS Gen2 override

After provisioning ADLS Gen2, the lakehouse managed identity, and the Iceberg REST catalog, copy the example override and replace placeholders:

```bash
cp workloads/query-engines/trino/kubernetes/helm/trino-iceberg-adls-values.example.yaml /tmp/trino-iceberg-adls-values.yaml
```

Install Trino with both files:

```bash
helm upgrade --install trino trino/trino \
  --version "$CHART_VERSION" \
  --namespace trino \
  --values workloads/query-engines/trino/kubernetes/helm/trino-values.yaml \
  --values /tmp/trino-iceberg-adls-values.yaml
```

## Internal load balancer override

If you need VNet-shared access instead of port-forward, create a small override file like this and keep it environment-specific:

```yaml
service:
  type: LoadBalancer
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
```
