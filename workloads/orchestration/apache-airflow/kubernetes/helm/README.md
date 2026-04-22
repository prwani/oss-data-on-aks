# Apache Airflow Helm assets

This folder holds the checked-in Helm values for the starter Airflow deployment.

- chart: `apache-airflow/airflow`
- chart version: `1.21.0`
- app version: `3.2.0`
- release name assumed by the docs: `airflow`

## Install sequence

```bash
kubectl apply -f workloads/orchestration/apache-airflow/kubernetes/manifests/namespace.yaml

helm repo add apache-airflow https://airflow.apache.org
helm repo update

helm upgrade --install airflow apache-airflow/airflow \
  --version 1.21.0 \
  --namespace airflow \
  --values workloads/orchestration/apache-airflow/kubernetes/helm/airflow-values.yaml
```

## Notes

- the values pin Airflow to `CeleryExecutor`
- the web UI is internal-only by default through an Azure internal load balancer
- DAGs are delivered with `git-sync`, not by baking DAGs into the container image
- PostgreSQL and Redis stay inside the chart for the starter scope boundary, but they still use durable PVCs on AKS
- the default admin-creation job is disabled so passwords are never committed to source control
- if you later add remote logging or DAG storage on Azure Storage, keep the repository rule: use managed identity-based access, not shared keys
