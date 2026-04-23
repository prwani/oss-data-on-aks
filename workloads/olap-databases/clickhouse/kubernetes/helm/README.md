# ClickHouse Helm assets

This folder contains the pinned Helm values for the ClickHouse starter blueprint.

## Install sequence

```bash
export CHART_VERSION=9.4.4

kubectl apply -f workloads/olap-databases/clickhouse/kubernetes/manifests/managed-csi-premium-storageclass.yaml
kubectl apply -f workloads/olap-databases/clickhouse/kubernetes/manifests/namespace.yaml

kubectl create secret generic clickhouse-auth --namespace clickhouse --from-literal=admin-password="$(openssl rand -base64 32 | tr -d '\n')"

helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm upgrade --install clickhouse bitnami/clickhouse --version "$CHART_VERSION" --namespace clickhouse --values workloads/olap-databases/clickhouse/kubernetes/helm/clickhouse-values.yaml
```

## Uninstall sequence

```bash
helm uninstall clickhouse -n clickhouse
kubectl delete pvc --all -n clickhouse --wait=false
kubectl delete namespace clickhouse --wait=true --timeout=600s
```

## Notes

- the values are pinned to Bitnami chart `9.4.4` and ClickHouse `25.7.5`
- the checked-in topology is `2 shards × 2 replicas` with `3 Keeper replicas`
- the chart expects the secret `clickhouse-auth` with key `admin-password`
- each ClickHouse and Keeper pod uses `managed-csi-premium` for its PVC
- the checked-in storage class manifest matches the AKS built-in `managed-csi-premium` class, so it is safe to apply on clusters where that class already exists
- the checked-in values override the image repositories to `docker.io/bitnamilegacy/...` because the pinned versioned `docker.io/bitnami/...` tags are no longer published
- uninstall the Helm release and delete the namespace before Terraform destroy or manual AKS deletion so the dedicated `clickhouse` pool can drain cleanly
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
