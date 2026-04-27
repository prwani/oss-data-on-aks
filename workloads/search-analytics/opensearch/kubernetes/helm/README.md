# OpenSearch Helm assets

This folder contains the starting Helm values for the three-release pattern used by the OpenSearch blueprint:

1. `manager-values.yaml`
2. `data-values.yaml`
3. `dashboards-values.yaml`

## Install sequence

```bash
export CHART_VERSION=3.6.0
export DASHBOARDS_CHART_VERSION=3.2.0
export SNAPSHOT_IDENTITY_CLIENT_ID=<snapshot-managed-identity-client-id>
export SNAPSHOT_STORAGE_ACCOUNT=<snapshot-storage-account-name>

kubectl apply -f workloads/search-analytics/opensearch/kubernetes/manifests/managed-csi-premium-storageclass.yaml
kubectl apply -f workloads/search-analytics/opensearch/kubernetes/manifests/namespace.yaml
kubectl create secret generic opensearch-snapshot-settings \
  --namespace opensearch \
  --from-literal=azure.client.default.account="$SNAPSHOT_STORAGE_ACCOUNT" \
  --dry-run=client -o yaml | kubectl apply -f -

helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm repo update

helm upgrade --install opensearch-manager opensearch/opensearch \
  --version "$CHART_VERSION" \
  --namespace opensearch \
  --set-string "rbac.serviceAccountAnnotations.azure\\.workload\\.identity/client-id=$SNAPSHOT_IDENTITY_CLIENT_ID" \
  --values workloads/search-analytics/opensearch/kubernetes/helm/manager-values.yaml

helm upgrade --install opensearch-data opensearch/opensearch \
  --version "$CHART_VERSION" \
  --namespace opensearch \
  --set-string "rbac.serviceAccountAnnotations.azure\\.workload\\.identity/client-id=$SNAPSHOT_IDENTITY_CLIENT_ID" \
  --values workloads/search-analytics/opensearch/kubernetes/helm/data-values.yaml

helm upgrade --install opensearch-dashboards opensearch/opensearch-dashboards \
  --version "$DASHBOARDS_CHART_VERSION" \
  --namespace opensearch \
  --values workloads/search-analytics/opensearch/kubernetes/helm/dashboards-values.yaml
```

## Notes

- the manager and data releases share the same `clusterName`
- the data release points `masterService` to the manager service
- Dashboards connects to the internal OpenSearch service and uses a secret-backed admin credential
- the manager and data values install `repository-azure`, load `azure.client.default.account` from the `opensearch-snapshot-settings` secret into the OpenSearch keystore, keep `azure.client.default.token_credential_type: managed_identity` in `opensearch.yml`, and create their own workload-identity service accounts when you pass the managed identity client ID with `--set-string`
- apply `managed-csi-premium-storageclass.yaml` before the Helm releases; it matches the AKS built-in `managed-csi-premium` definition and can also create the class on clusters that do not expose it yet
- apply `namespace.yaml` before the Helm releases so the namespace allows the chart's privileged sysctl init container to set `vm.max_map_count`
- the default values expect dedicated `osmgr` and `osdata` pools with three schedulable nodes each because both StatefulSets use three replicas with hard pod anti-affinity
- the checked-in snapshot path is intentionally keyless; use the managed identity client ID from the infrastructure outputs and do not reintroduce storage account keys or SAS tokens
- pin the chart version you validated; this blueprint is currently aligned to `3.6.0`
- update selectors and tolerations if your AKS node pool labels or taints differ from the examples
