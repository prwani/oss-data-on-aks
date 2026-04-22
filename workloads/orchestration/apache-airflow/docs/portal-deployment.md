# Apache Airflow portal deployment path

Use this guide when the team wants to validate the target AKS shape in the Azure portal before standardizing on automation.

## Outcome

You should end with:

- an AKS cluster created from the shared AVM-aligned pattern
- a dedicated `airflow` user pool with three nodes
- an `airflow` namespace
- Helm release `airflow` running scheduler, API server, webserver, triggerer, workers, PostgreSQL, and Redis
- an internal-only Airflow UI

## Step 1: Review the blueprint assets

Before using the portal, review the checked-in target state:

- architecture: `docs/architecture.md`
- Helm values: `kubernetes/helm/airflow-values.yaml`
- namespace manifest: `kubernetes/manifests/namespace.yaml`
- runtime bootstrap notes: `kubernetes/manifests/README.md`

## Step 2: Create or align the resource group

Suggested names:

- resource group: `rg-apache-airflow-aks-dev`
- cluster: `aks-apache-airflow-dev`

Keeping those names aligned with the IaC files makes the later Terraform or Bicep path friction-free.

## Step 3: Create the AKS cluster in the portal

Mirror the AVM-oriented design decisions:

1. choose the target region
2. keep managed identity enabled
3. enable Azure Monitor if your platform standard expects it
4. keep the AKS API private if that matches your landing zone policy
5. create the default system pool
6. add a user pool named `airflow` with 3 Linux nodes

### Suggested `airflow` pool settings

| Setting | Value |
| --- | --- |
| Node pool name | `airflow` |
| Mode | `User` |
| Node count | `3` |
| VM size | `Standard_D4s_v5` |
| Taint | `dedicated=airflow:NoSchedule` |

## Step 4: Connect to AKS and create the namespace

```bash
az aks get-credentials \
  --resource-group rg-apache-airflow-aks-dev \
  --name aks-apache-airflow-dev

kubectl apply -f workloads/orchestration/apache-airflow/kubernetes/manifests/namespace.yaml
```

## Step 5: Create the runtime secrets

The checked-in Helm values expect external secrets for the Airflow crypto material and for the starter PostgreSQL and Redis credentials.

```bash
export AIRFLOW_NS=airflow
export AIRFLOW_RELEASE=airflow
export AIRFLOW_ADMIN_EMAIL="${AIRFLOW_ADMIN_EMAIL:?Set AIRFLOW_ADMIN_EMAIL to a real email address before continuing}"
export AIRFLOW_POSTGRES_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
export AIRFLOW_REDIS_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
export AIRFLOW_FERNET_KEY="$(openssl rand -base64 32 | tr '+/' '-_' | tr -d '\n')"
export AIRFLOW_API_SECRET="$(openssl rand -hex 32)"
export AIRFLOW_JWT_SECRET="$(openssl rand -hex 32)"
export AIRFLOW_WEBSERVER_SECRET="$(openssl rand -hex 32)"
export AIRFLOW_ADMIN_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"

kubectl create secret generic airflow-postgresql-auth -n "$AIRFLOW_NS" \
  --from-literal=password="$AIRFLOW_POSTGRES_PASSWORD"

kubectl create secret generic airflow-redis-password -n "$AIRFLOW_NS" \
  --from-literal=password="$AIRFLOW_REDIS_PASSWORD"

kubectl create secret generic airflow-metadata -n "$AIRFLOW_NS" \
  --from-literal=connection="postgresql+psycopg2://airflow:${AIRFLOW_POSTGRES_PASSWORD}@${AIRFLOW_RELEASE}-postgresql:5432/airflow"

kubectl create secret generic airflow-result-backend -n "$AIRFLOW_NS" \
  --from-literal=connection="db+postgresql://airflow:${AIRFLOW_POSTGRES_PASSWORD}@${AIRFLOW_RELEASE}-postgresql:5432/airflow"

kubectl create secret generic airflow-broker-url -n "$AIRFLOW_NS" \
  --from-literal=connection="redis://:${AIRFLOW_REDIS_PASSWORD}@${AIRFLOW_RELEASE}-redis:6379/0"

kubectl create secret generic airflow-fernet-key -n "$AIRFLOW_NS" \
  --from-literal=fernet-key="$AIRFLOW_FERNET_KEY"

kubectl create secret generic airflow-api-secret -n "$AIRFLOW_NS" \
  --from-literal=api-secret-key="$AIRFLOW_API_SECRET"

kubectl create secret generic airflow-jwt-secret -n "$AIRFLOW_NS" \
  --from-literal=jwt-secret="$AIRFLOW_JWT_SECRET"

kubectl create secret generic airflow-webserver-secret -n "$AIRFLOW_NS" \
  --from-literal=webserver-secret-key="$AIRFLOW_WEBSERVER_SECRET"
```

## Step 6: Install Airflow

```bash
helm repo add apache-airflow https://airflow.apache.org
helm repo update

helm upgrade --install airflow apache-airflow/airflow \
  --version 1.21.0 \
  --namespace airflow \
  --values workloads/orchestration/apache-airflow/kubernetes/helm/airflow-values.yaml
```

## Step 7: Create the initial admin user

The chart values intentionally disable the default admin-creation job so no password is committed to source control.

```bash
kubectl exec -n airflow deploy/airflow-api-server -- \
  airflow users create \
    --role Admin \
    --username admin \
    --email "$AIRFLOW_ADMIN_EMAIL" \
    --firstname Platform \
    --lastname Admin \
    --password "$AIRFLOW_ADMIN_PASSWORD"
```

## Step 8: Validate the deployment

```bash
kubectl get pods -n airflow
kubectl get svc -n airflow
kubectl get jobs -n airflow
kubectl describe svc airflow-webserver -n airflow
kubectl logs deploy/airflow-scheduler -n airflow --tail=100
```

Check for:

- two healthy scheduler pods
- two healthy webserver pods and an internal load balancer IP on `airflow-webserver`
- a running triggerer and at least three worker pods
- `airflow-postgresql` and `airflow-redis` PVCs bound successfully
- a completed database migration job

## Portal-specific review points

- confirm the `airflow` node pool has the expected VM size and taint
- confirm the Airflow web service is internal-only
- confirm the PostgreSQL and Redis PVCs landed on Premium managed disks
- confirm the DAG sync sidecars can reach the public Git source or swap to a private source before production rollout
