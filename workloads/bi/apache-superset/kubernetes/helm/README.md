# Apache Superset Helm assets

This folder holds the checked-in Helm values for the starter Superset deployment.

- chart: `superset/superset`
- chart version: `0.15.4`
- app version: `5.0.0`
- release name assumed by the docs: `superset`

## Install sequence

```bash
kubectl apply -f workloads/bi/apache-superset/kubernetes/manifests/namespace.yaml

kubectl create secret generic superset-postgresql-auth -n superset \
  --from-literal=password="$SUPERSET_POSTGRES_PASSWORD"

kubectl create secret generic superset-env -n superset \
  --from-literal=DB_HOST="superset-postgresql" \
  --from-literal=DB_PORT="5432" \
  --from-literal=DB_USER="superset" \
  --from-literal=DB_PASS="$SUPERSET_POSTGRES_PASSWORD" \
  --from-literal=DB_NAME="superset" \
  --from-literal=REDIS_HOST="superset-redis-headless" \
  --from-literal=REDIS_PORT="6379" \
  --from-literal=REDIS_PROTO="redis" \
  --from-literal=REDIS_DB="1" \
  --from-literal=REDIS_CELERY_DB="0" \
  --from-literal=SUPERSET_SECRET_KEY="$SUPERSET_SECRET_KEY"

helm repo add superset https://apache.github.io/superset
helm repo update

helm upgrade --install superset superset/superset \
  --version 0.15.4 \
  --namespace superset \
  --values workloads/bi/apache-superset/kubernetes/helm/superset-values.yaml

kubectl wait --for=condition=complete job/superset-init-db -n superset --timeout=15m
kubectl wait --for=condition=available deployment/superset -n superset --timeout=10m
```

## Notes

- the values expect externally created `superset-env` and `superset-postgresql-auth` secrets so no fake passwords or secret keys land in Git
- the web UI is internal-only by default through an Azure internal load balancer
- the chart-managed `superset-init-db` hook job runs schema migrations and `superset init`; treat it as a rollout dependency, not background noise
- create the first admin user after the install with `kubectl exec deploy/superset -- superset fab create-admin ...`; the chart intentionally does not store an admin password in values
- web pods, worker pods, PostgreSQL, and Redis all target the dedicated `superset` node pool
- PostgreSQL and Redis use durable `managed-csi-premium` PVCs; if your AKS cluster uses a different Premium CSI class, update the storage class names before installation
- Celery beat, Flower, and websocket pods stay disabled in the starter until alerts, reports, or live queue monitoring are part of the design
- the created `superset` service account gives you a clean anchor point for workload identity later if you add Azure Storage-backed exports or logs
