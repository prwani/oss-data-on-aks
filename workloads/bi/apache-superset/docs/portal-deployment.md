# Apache Superset portal deployment path

Use this guide when the team wants to validate the target AKS shape in the Azure portal before standardizing on automation.

## Outcome

You should end with:

- an AKS cluster created from the shared AVM-aligned pattern
- a dedicated `superset` user pool with three nodes
- a `superset` namespace
- Helm release `superset` running web pods, Celery workers, PostgreSQL, Redis, and the `superset-init-db` hook job
- an internal-only Superset UI

## Step 1: Review the blueprint assets

Before using the portal, review the checked-in target state:

- architecture: `docs/architecture.md`
- Helm values: `kubernetes/helm/superset-values.yaml`
- storage class manifest: `kubernetes/manifests/managed-csi-premium-storageclass.yaml`
- namespace manifest: `kubernetes/manifests/namespace.yaml`
- runtime bootstrap notes: `kubernetes/manifests/README.md`

## Step 2: Create or align the resource group

Suggested names:

- resource group: `rg-apache-superset-aks-dev`
- cluster: `aks-apache-superset-dev`

Keeping those names aligned with the IaC files makes the later Terraform or Bicep path friction-free.

## Step 3: Create the AKS cluster in the portal

Mirror the AVM-oriented design decisions:

1. choose the target region
2. keep managed identity enabled
3. enable Azure Monitor if your platform standard expects it
4. keep the AKS API private if that matches your landing zone policy
5. create the default system pool
6. add a user pool named `superset` with 3 Linux nodes

### Suggested `superset` pool settings

| Setting | Value |
| --- | --- |
| Node pool name | `superset` |
| Mode | `User` |
| Node count | `3` |
| VM size | `Standard_D4s_v5` |
| Taint | `dedicated=superset:NoSchedule` |
| Label | `workload=apache-superset` |

## Step 4: Connect to AKS and create the namespace and storage class

```bash
az aks get-credentials \
  --resource-group rg-apache-superset-aks-dev \
  --name aks-apache-superset-dev

kubectl apply -f workloads/bi/apache-superset/kubernetes/manifests/namespace.yaml
kubectl apply -f workloads/bi/apache-superset/kubernetes/manifests/managed-csi-premium-storageclass.yaml
```

## Step 5: Create the runtime secrets

The checked-in Helm values expect external secrets for the Superset metadata database password and for the runtime environment consumed by the web tier, workers, and init job.

```bash
export SUPERSET_NS=superset
export SUPERSET_RELEASE=superset
export SUPERSET_POSTGRES_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
export SUPERSET_SECRET_KEY="$(openssl rand -base64 42 | tr -d '\n')"
export SUPERSET_ADMIN_EMAIL="${SUPERSET_ADMIN_EMAIL:?Set SUPERSET_ADMIN_EMAIL to a real email address before continuing}"
export SUPERSET_ADMIN_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"

kubectl create secret generic superset-postgresql-auth -n "$SUPERSET_NS" \
  --from-literal=password="$SUPERSET_POSTGRES_PASSWORD"

kubectl create secret generic superset-env -n "$SUPERSET_NS" \
  --from-literal=DB_HOST="${SUPERSET_RELEASE}-postgresql" \
  --from-literal=DB_PORT="5432" \
  --from-literal=DB_USER="superset" \
  --from-literal=DB_PASS="$SUPERSET_POSTGRES_PASSWORD" \
  --from-literal=DB_NAME="superset" \
  --from-literal=REDIS_HOST="${SUPERSET_RELEASE}-redis-headless" \
  --from-literal=REDIS_PORT="6379" \
  --from-literal=REDIS_PROTO="redis" \
  --from-literal=REDIS_DB="1" \
  --from-literal=REDIS_CELERY_DB="0" \
  --from-literal=SUPERSET_SECRET_KEY="$SUPERSET_SECRET_KEY"
```

## Step 6: Install Superset

```bash
helm repo add superset https://apache.github.io/superset
helm repo update

helm upgrade --install superset superset/superset \
  --version 0.15.4 \
  --namespace superset \
  --values workloads/bi/apache-superset/kubernetes/helm/superset-values.yaml
```

## Step 7: Wait for the init job and create the first admin user

The chart values intentionally disable default admin-user creation so no password is committed to source control.

```bash
kubectl wait --for=condition=complete job/superset-init-db -n "$SUPERSET_NS" --timeout=15m
kubectl wait --for=condition=available deployment/superset -n "$SUPERSET_NS" --timeout=10m

kubectl exec -n "$SUPERSET_NS" deploy/superset -- \
  superset fab create-admin \
    --username admin \
    --firstname Platform \
    --lastname Admin \
    --email "$SUPERSET_ADMIN_EMAIL" \
    --password "$SUPERSET_ADMIN_PASSWORD"
```

## Step 8: Validate the deployment

```bash
kubectl get pods -n "$SUPERSET_NS"
kubectl get jobs -n "$SUPERSET_NS"
kubectl get pvc -n "$SUPERSET_NS"
kubectl get storageclass managed-csi-premium
kubectl get svc -n "$SUPERSET_NS"
kubectl logs job/superset-init-db -n "$SUPERSET_NS" --tail=100
kubectl describe svc superset -n "$SUPERSET_NS"
```

For a quick UI check without exposing the service publicly:

```bash
kubectl port-forward svc/superset 8088:8088 -n "$SUPERSET_NS"
```

Check for:

- two healthy web pods in the `superset` deployment
- at least two healthy worker pods in `superset-worker`
- a completed `superset-init-db` job
- the `managed-csi-premium` storage class exists and the chart-managed PostgreSQL and Redis PVCs are bound
- an internal load balancer IP on the `superset` service

## Portal-specific review points

- confirm the `superset` node pool has the expected VM size, label, and taint
- confirm the web pods, worker pods, and the `superset-init-db` job pod land on the `superset` node pool; PostgreSQL and Redis should do the same
- confirm the Superset service is internal-only
- confirm the PostgreSQL and Redis PVCs landed on Premium managed disks or the intended storage class for your cluster
- confirm the cluster has outbound reachability to the external data sources you plan to register in Superset
- confirm `superset-init-db` finishes successfully after install and again after any upgrade rehearsal
