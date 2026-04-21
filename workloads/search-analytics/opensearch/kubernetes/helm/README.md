# OpenSearch Helm assets

This folder contains the starting Helm values for the three-release pattern used by the OpenSearch blueprint:

1. `manager-values.yaml`
2. `data-values.yaml`
3. `dashboards-values.yaml`

## Install sequence

```bash
helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm repo update

helm upgrade --install opensearch-manager opensearch/opensearch \
  --namespace opensearch \
  --values workloads/search-analytics/opensearch/kubernetes/helm/manager-values.yaml

helm upgrade --install opensearch-data opensearch/opensearch \
  --namespace opensearch \
  --values workloads/search-analytics/opensearch/kubernetes/helm/data-values.yaml

helm upgrade --install opensearch-dashboards opensearch/opensearch-dashboards \
  --namespace opensearch \
  --values workloads/search-analytics/opensearch/kubernetes/helm/dashboards-values.yaml
```

## Notes

- the manager and data releases share the same `clusterName`
- the data release points `masterService` to the manager service
- Dashboards connects to the internal OpenSearch service and uses a secret-backed admin credential
- update selectors and tolerations if your AKS node pool labels or taints differ from the examples
