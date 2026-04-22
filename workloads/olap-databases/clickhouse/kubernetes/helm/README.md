# ClickHouse Helm assets

This folder contains the pinned Helm values for the ClickHouse starter blueprint.

## Install sequence

```bash
export CHART_VERSION=9.4.7

kubectl apply -f workloads/olap-databases/clickhouse/kubernetes/manifests/managed-csi-premium-storageclass.yaml
kubectl apply -f workloads/olap-databases/clickhouse/kubernetes/manifests/namespace.yaml

kubectl create secret generic clickhouse-auth --namespace clickhouse --from-literal=admin-password="$(openssl rand -base64 32 | tr -d '\n')"

helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm upgrade --install clickhouse bitnami/clickhouse --version "$CHART_VERSION" --namespace clickhouse --values workloads/olap-databases/clickhouse/kubernetes/helm/clickhouse-values.yaml
```

## Notes

- the values are pinned to Bitnami chart `9.4.7` and ClickHouse `25.7.5`
- the checked-in topology is `2 shards × 2 replicas` with `3 Keeper replicas`
- the chart expects the secret `clickhouse-auth` with key `admin-password`
- each ClickHouse and Keeper pod uses `managed-csi-premium` for its PVC
- the service stays `ClusterIP` by default so operator access uses port-forward or an internal-only path

## Internal load balancer override

If you need VNet-shared access instead of port-forward, create a small override file like this and keep it environment-specific:

```yaml
service:
  type: LoadBalancer
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
```

Keep Keeper on `ClusterIP` and leave the checked-in default private.
