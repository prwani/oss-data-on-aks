# Apache Superset `az` CLI deployment path

Use this path when you want the cluster foundation and workload deployment captured as code.

## Prerequisites

- Azure CLI
- `kubectl`
- Helm 3.x
- OpenSSL for local secret generation
- Terraform 1.11+ if you want the Terraform path

## Environment variables

```bash
export LOCATION=eastus
export RESOURCE_GROUP=rg-apache-superset-aks-dev
export CLUSTER_NAME=aks-apache-superset-dev
export SUPERSET_NAMESPACE=superset
export SUPERSET_RELEASE=superset
export SUPERSET_POSTGRES_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
export SUPERSET_SECRET_KEY="$(openssl rand -base64 42 | tr -d '\n')"
export SUPERSET_ADMIN_EMAIL="${SUPERSET_ADMIN_EMAIL:?Set SUPERSET_ADMIN_EMAIL to a real email address before continuing}"
export SUPERSET_ADMIN_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
export SUPERSET_HELM_VERSION=0.15.4
```

## Option A: Bicep wrapper

```bash
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file workloads/bi/apache-superset/infra/bicep/main.bicep \
  --parameters \
      clusterName="$CLUSTER_NAME" \
      location="$LOCATION"
```

This wrapper creates the shared AKS baseline plus the dedicated `superset` user pool defined for the workload.

## Option B: Terraform wrapper

```bash
cd workloads/bi/apache-superset/infra/terraform
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform plan
terraform apply
```

## Connect to AKS

```bash
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME"
```

## Create the namespace and secrets

```bash
kubectl apply -f workloads/bi/apache-superset/kubernetes/manifests/namespace.yaml

kubectl create secret generic superset-postgresql-auth -n "$SUPERSET_NAMESPACE" \
  --from-literal=password="$SUPERSET_POSTGRES_PASSWORD"

kubectl create secret generic superset-env -n "$SUPERSET_NAMESPACE" \
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

## Install Superset

```bash
helm repo add superset https://apache.github.io/superset
helm repo update

helm upgrade --install superset superset/superset \
  --version "$SUPERSET_HELM_VERSION" \
  --namespace "$SUPERSET_NAMESPACE" \
  --values workloads/bi/apache-superset/kubernetes/helm/superset-values.yaml
```

## Wait for migrations and create the first admin user

```bash
kubectl wait --for=condition=complete job/superset-init-db -n "$SUPERSET_NAMESPACE" --timeout=15m
kubectl wait --for=condition=available deployment/superset -n "$SUPERSET_NAMESPACE" --timeout=10m

kubectl exec -n "$SUPERSET_NAMESPACE" deploy/superset -- \
  superset fab create-admin \
    --username admin \
    --firstname Platform \
    --lastname Admin \
    --email "$SUPERSET_ADMIN_EMAIL" \
    --password "$SUPERSET_ADMIN_PASSWORD"
```

## Validate the deployment

```bash
kubectl get pods -n "$SUPERSET_NAMESPACE"
kubectl get jobs -n "$SUPERSET_NAMESPACE"
kubectl get pvc -n "$SUPERSET_NAMESPACE"
kubectl get svc -n "$SUPERSET_NAMESPACE"
kubectl logs job/superset-init-db -n "$SUPERSET_NAMESPACE" --tail=100
kubectl logs deploy/superset -n "$SUPERSET_NAMESPACE" --tail=100
kubectl logs deploy/superset-worker -n "$SUPERSET_NAMESPACE" --tail=100
kubectl describe svc superset -n "$SUPERSET_NAMESPACE"
```

For a quick UI check without exposing the service publicly:

```bash
kubectl port-forward svc/superset 8088:8088 -n "$SUPERSET_NAMESPACE"
```

## Implementation notes

- the Superset UI stays internal by default
- the `superset-init-db` job is part of every install or upgrade and must complete before the rollout is healthy
- chart-managed PostgreSQL and Redis are acceptable starter scope boundaries, but move them out when you need independent patching, stronger backup posture, or cross-zone database design
- Celery beat and Flower stay disabled until you explicitly add scheduled reports or queue monitoring
- if you later add Azure Storage-backed exports, logs, or artifacts, bind a managed identity to the `superset` service account instead of storing account keys or shared secrets
