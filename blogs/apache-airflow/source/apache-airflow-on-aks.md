# Running Apache Airflow on AKS with dedicated schedulers, workers, and an internal-only UI

**Publication target:** Microsoft TechCommunity > Azure > Linux and Open Source Blog

## Summary

Apache Airflow is often demoed as a UI plus `helm install`, but a reusable AKS blueprint has to account for the scheduler, API server, webserver, triggerer, Celery workers, metadata state, Redis queueing, and DAG delivery across all of them.

This post walks through a starter blueprint for Apache Airflow 3.2.0 on Azure Kubernetes Service (AKS) using the official `apache-airflow/airflow` chart 1.21.0, a dedicated `airflow` node pool, `git-sync`-based DAG delivery, bundled PostgreSQL and Redis as the starter scope boundary, and checked-in Terraform, Bicep, Helm, and operations assets.

## Why Airflow on AKS is not just another web app

This is the key AKS design point: **Airflow is not a single stateless frontend deployment**.

A useful Airflow environment on AKS includes:

- a scheduler that evaluates DAGs and task dependencies
- an API server for Airflow 3 control-plane traffic
- a webserver for human operators
- a triggerer for deferred tasks
- Celery workers that execute user code
- PostgreSQL for metadata
- Redis for Celery transport
- a DAG delivery mechanism that keeps every pod in sync
- runtime secrets for the fernet key, API secrets, JWT signing, and the webserver secret

That is a very different shape from a typical microservice that can be summarized as `Deployment + Service + external database`.

## What the repo now provides

The Airflow workload in this repo is organized around five concrete building blocks:

1. AKS AVM-based Terraform and Bicep wrappers under `workloads/orchestration/apache-airflow/infra`
2. Airflow architecture, portal, CLI, and operations guidance under `workloads/orchestration/apache-airflow/docs`
3. Helm values and namespace assets under `workloads/orchestration/apache-airflow/kubernetes`
4. a starter node-pool layout that uses a dedicated `airflow` AKS user pool
5. publish-ready blog assets under `blogs/apache-airflow`

## Checked-in version contract

These are the repo-backed versions this walkthrough currently matches.

| Component | Checked-in version | Evidence in repo |
| --- | --- | --- |
| Helm chart | `apache-airflow/airflow` `1.21.0` | `workloads/orchestration/apache-airflow/kubernetes/helm/README.md` |
| Airflow runtime | `3.2.0` | `workloads/orchestration/apache-airflow/kubernetes/helm/README.md` |
| Deployment values | `airflow-values.yaml` aligned to chart `1.21.0` | `workloads/orchestration/apache-airflow/kubernetes/helm/airflow-values.yaml` |

## The target AKS pattern

The blueprint uses these opinions by default:

| Layer | Recommendation | Why |
| --- | --- | --- |
| AKS baseline | Shared AVM wrapper | Keeps cluster creation consistent across workloads |
| Workload placement | Dedicated `airflow` node pool with 3 nodes | Isolates orchestration traffic and starter stateful dependencies |
| Executor | `CeleryExecutor` | Makes worker scale-out explicit |
| DAG distribution | `git-sync` | Gives every Airflow pod the same DAG set |
| Metadata DB | Bundled PostgreSQL | Keeps the starter runnable without an extra managed service |
| Broker | Bundled Redis | Makes Celery execution concrete immediately |
| UI exposure | Internal Azure load balancer | Keeps the UI private by default |

The checked-in values make that topology concrete: two API servers, two schedulers, two webservers, two triggerers, three Celery workers, a 16 GiB PostgreSQL PVC, an 8 GiB Redis PVC, and `git-sync` polling the Apache Airflow example DAGs every 30 seconds.

## Prerequisites and environment contract

Before you start, make sure you have:

- an Azure subscription with AKS quota for the dedicated `airflow` node pool
- Azure CLI installed and logged in
- `kubectl` installed
- Helm 3.x installed
- OpenSSL available for local secret generation
- Terraform 1.11+ if you want the Terraform path
- a real admin email address for the first Airflow user

The repo-backed CLI path uses this environment contract:

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

## Step 1: Deploy or align the AKS baseline

The repo keeps both IaC entry points visible because different teams standardize differently.

### Bicep path

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

### Terraform path

```bash
cd workloads/orchestration/apache-airflow/infra/terraform
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform plan
terraform apply
```

Both wrappers create `systempool` plus a dedicated `airflow` user pool with three nodes and the `dedicated=airflow:NoSchedule` taint.

## Step 2: Create the namespace, storage class, and runtime secrets

Once AKS is ready, connect to the cluster and create the Kubernetes-native prerequisites that the chart expects:

```bash
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME"

kubectl apply -f workloads/orchestration/apache-airflow/kubernetes/manifests/namespace.yaml
kubectl apply -f workloads/orchestration/apache-airflow/kubernetes/manifests/managed-csi-premium-storageclass.yaml

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

The storage class step matters because the checked-in PostgreSQL and Redis values expect `managed-csi-premium` for their durable PVCs.

That secret contract is part of the platform design. The chart-managed admin-creation job stays disabled, and the repo never has to carry placeholder passwords or fake keys.

## Step 3: Install Airflow with the pinned chart

```bash
helm repo add apache-airflow https://airflow.apache.org
helm repo update

helm upgrade --install airflow apache-airflow/airflow \
  --version "$AIRFLOW_HELM_VERSION" \
  --namespace "$AIRFLOW_NAMESPACE" \
  --values workloads/orchestration/apache-airflow/kubernetes/helm/airflow-values.yaml
```

The checked-in values do the important AKS-specific work up front:

- pin the executor to **`CeleryExecutor`**
- keep the web UI behind an **internal** Azure load balancer
- bind the Airflow control plane, workers, PostgreSQL, and Redis to the dedicated `airflow` node pool
- enable durable PVCs for PostgreSQL and Redis while leaving worker logs ephemeral
- deliver DAGs with **`git-sync`** instead of baking DAG content into the image

## Step 4: Create the first admin account and validate the platform shape

Once the API server is up, create the first admin user:

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

Then validate the parts that actually matter for Airflow on AKS:

```bash
kubectl get pods -n "$AIRFLOW_NAMESPACE"
kubectl get svc -n "$AIRFLOW_NAMESPACE"
kubectl get jobs -n "$AIRFLOW_NAMESPACE"
kubectl get pvc -n "$AIRFLOW_NAMESPACE"
kubectl get storageclass managed-csi-premium
kubectl logs deploy/airflow-scheduler -n "$AIRFLOW_NAMESPACE" --tail=100
kubectl describe svc airflow-webserver -n "$AIRFLOW_NAMESPACE"
```

For a quick UI check without exposing the service publicly:

```bash
kubectl port-forward svc/airflow-webserver 8080:8080 -n "$AIRFLOW_NAMESPACE"
```

If those checks look healthy, you have validated the real starter contract: multiple control-plane pods, durable state for PostgreSQL and Redis, a private UI endpoint, and a DAG delivery path that can reach every Airflow component.

## The AKS-specific differences to keep in mind

If you are used to stateless application services, these are the Airflow-on-AKS behaviors to internalize early:

1. **The control plane is multi-component.** API server, scheduler, triggerer, webserver, and workers each matter independently.
2. **DAG delivery is part of the platform contract.** Helm alone is not enough if the pods do not share the same DAG tree.
3. **Starter PostgreSQL and Redis still need real storage validation.** `kubectl get pvc` and a quick storage-class check belong in the smoke test.
4. **Private access is the better default.** An internal load balancer is safer while the platform still uses runtime-created credentials.
5. **Secret creation is a deployment step, not a Git artifact.** Fernet keys, webserver secrets, JWT secrets, and passwords should never live in the repo.

## Azure integration notes

This starter intentionally keeps Azure dependencies light. It does not wire Azure Storage, managed PostgreSQL, or external Redis by default. That is a scope boundary, not a dead end.

If you extend the design later for remote logging, DAG storage, or artifact exchange, keep the same repo rule intact: use workload identity or another managed identity-based path instead of storage account shared keys.

## Closing thought

Airflow on AKS becomes much easier to operate when the repo makes the platform shape explicit: multiple control-plane components, worker isolation, runtime secret delivery, DAG sync, and starter stateful dependencies with real validation steps.

That is what this blueprint now provides. It is not pretending to be a one-click production platform, but it is a credible AKS starter that a platform team can evolve without throwing away the first implementation.
