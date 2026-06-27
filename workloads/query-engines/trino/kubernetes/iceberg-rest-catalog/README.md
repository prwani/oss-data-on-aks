# Iceberg REST catalog assets

This folder contains starter Kubernetes assets for deploying an Iceberg REST catalog with Apache Polaris.

## Install sequence

Create the namespace:

```bash
kubectl apply -f workloads/query-engines/trino/kubernetes/iceberg-rest-catalog/namespace.yaml
```

Create a PostgreSQL connection secret for Polaris metadata:

```bash
kubectl create secret generic polaris-postgresql -n iceberg-catalog \
  --from-literal=username="$POLARIS_POSTGRES_USER" \
  --from-literal=password="$POLARIS_POSTGRES_PASSWORD" \
  --from-literal=jdbcUrl="$POLARIS_POSTGRES_JDBC_URL"
```

Install Polaris with the Apache Polaris Helm chart:

```bash
helm repo add apache-polaris https://downloads.apache.org/polaris/helm-chart/
helm repo update

helm upgrade --install polaris apache-polaris/polaris \
  --namespace iceberg-catalog \
  --values workloads/query-engines/trino/kubernetes/iceberg-rest-catalog/polaris-values.example.yaml
```

## Notes

- The checked-in values are an environment-specific starter, not a secret store. Replace placeholders with deployment outputs before use.
- The service account annotation and pod label enable Azure Workload Identity for ADLS Gen2 access.
- The default production direction is relational JDBC persistence backed by Azure Database for PostgreSQL Flexible Server.
- Keep the Polaris service private inside the cluster and let Trino reach it through `http://polaris.iceberg-catalog.svc.cluster.local:8181`.
