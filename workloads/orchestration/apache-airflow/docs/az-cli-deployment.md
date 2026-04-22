# Apache Airflow `az` CLI deployment path

Use this path when you want the cluster foundation and workload deployment captured as code.

## Prerequisites

- Azure CLI
- `kubectl`
- Helm 3.x
- Terraform 1.11+ if you want the Terraform path
- OpenSSL for local secret generation

## Environment variables

```bash
export LOCATION=eastus
export RESOURCE_GROUP=rg-apache-airflow-aks-dev
export CLUSTER_NAME=aks-apache-airflow-dev
export AIRFLOW_NAMESPACE=airflow
export AIRFLOW_ADMIN_EMAIL="${AIRFLOW_ADMIN_EMAIL:?Set AIRFLOW_ADMIN_EMAIL to a real email address before continuing}"
export AIRFLOW_POSTGRES_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
export AIRFLOW_REDIS_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
export AIRFLOW_FERNET_KEY="$(openssl rand -base64 32 | tr '+/' '-_' | tr -d '\n')"
export AIRFLOW_API_SECRET="$(openssl rand -hex 32)"
export AIRFLOW_JWT_SECRET="$(openssl rand -hex 32)"
export AIRFLOW_WEBSERVER_SECRET="$(openssl rand -hex 32)"
export AIRFLOW_ADMIN_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
export AIRFLOW_HELM_VERSION=1.21.0
```

## Option A: Bicep wrapper

```bash
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file workloads/orchestration/apache-airflow/infra/bicep/main.bicep \
  --parameters \
      clusterName="$CLUSTER_NAME" \
      location="$LOCATION"
```

This wrapper creates the shared AKS baseline plus the dedicated `airflow` user pool defined for the workload.

## Option B: Terraform wrapper

```bash
cd workloads/orchestration/apache-airflow/infra/terraform
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
kubectl apply -f workloads/orchestration/apache-airflow/kubernetes/manifests/namespace.yaml

kubectl create secret generic airflow-postgresql-auth -n "$AIRFLOW_NAMESPACE" \
  --from-literal=password="$AIRFLOW_POSTGRES_PASSWORD"

kubectl create secret generic airflow-redis-password -n "$AIRFLOW_NAMESPACE" \
  --from-literal=password="$AIRFLOW_REDIS_PASSWORD"

kubectl create secret generic airflow-metadata -n "$AIRFLOW_NAMESPACE" \
  --from-literal=connection="postgresql+psycopg2://airflow:${AIRFLOW_POSTGRES_PASSWORD}@airflow-postgresql:5432/airflow"

kubectl create secret generic airflow-result-backend -n "$AIRFLOW_NAMESPACE" \
  --from-literal=connection="db+postgresql://airflow:${AIRFLOW_POSTGRES_PASSWORD}@airflow-postgresql:5432/airflow"

kubectl create secret generic airflow-broker-url -n "$AIRFLOW_NAMESPACE" \
  --from-literal=connection="redis://:${AIRFLOW_REDIS_PASSWORD}@airflow-redis:6379/0"

kubectl create secret generic airflow-fernet-key -n "$AIRFLOW_NAMESPACE" \
  --from-literal=fernet-key="$AIRFLOW_FERNET_KEY"

kubectl create secret generic airflow-api-secret -n "$AIRFLOW_NAMESPACE" \
  --from-literal=api-secret-key="$AIRFLOW_API_SECRET"

kubectl create secret generic airflow-jwt-secret -n "$AIRFLOW_NAMESPACE" \
  --from-literal=jwt-secret="$AIRFLOW_JWT_SECRET"

kubectl create secret generic airflow-webserver-secret -n "$AIRFLOW_NAMESPACE" \
  --from-literal=webserver-secret-key="$AIRFLOW_WEBSERVER_SECRET"
```

## Install Airflow

```bash
helm repo add apache-airflow https://airflow.apache.org
helm repo update

helm upgrade --install airflow apache-airflow/airflow \
  --version "$AIRFLOW_HELM_VERSION" \
  --namespace "$AIRFLOW_NAMESPACE" \
  --values workloads/orchestration/apache-airflow/kubernetes/helm/airflow-values.yaml
```

## Create the first admin account

```bash
kubectl exec -n "$AIRFLOW_NAMESPACE" deploy/airflow-api-server -- \
  airflow users create \
    --role Admin \
    --username admin \
    --email "$AIRFLOW_ADMIN_EMAIL" \
    --firstname Platform \
    --lastname Admin \
    --password "$AIRFLOW_ADMIN_PASSWORD"
```

## Validate the deployment

```bash
kubectl get pods -n "$AIRFLOW_NAMESPACE"
kubectl get svc -n "$AIRFLOW_NAMESPACE"
kubectl get jobs -n "$AIRFLOW_NAMESPACE"
kubectl logs deploy/airflow-scheduler -n "$AIRFLOW_NAMESPACE" --tail=100
kubectl describe svc airflow-webserver -n "$AIRFLOW_NAMESPACE"
```

For a quick UI check without exposing the service publicly:

```bash
kubectl port-forward svc/airflow-webserver 8080:8080 -n "$AIRFLOW_NAMESPACE"
```

## Implementation notes

- the Airflow UI stays internal by default
- the blueprint assumes the Helm release name `airflow`
- bundled PostgreSQL and Redis are acceptable only as the starter scope boundary; move them out when you need higher durability, independent patching, or cross-zone database strategies
- if you later enable remote logging or DAG storage on Azure Storage, use workload identity or another managed identity-based path instead of shared keys
