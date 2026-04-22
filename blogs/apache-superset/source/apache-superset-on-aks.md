# Running Apache Superset on AKS with Celery workers, metadata state, and an internal-only UI

**Publication target:** Microsoft TechCommunity > Azure > Linux and Open Source Blog

## Summary

Apache Superset is easy to demo as a web UI with a quick Helm command. That shortcut hides what matters on AKS: the web tier, Celery workers, metadata database, Redis, the init and migration job, and the fact that Superset connects out to analytics engines instead of holding the business data itself.

This post walks through a starter blueprint for Apache Superset 5.0.0 on Azure Kubernetes Service (AKS) using the official `superset/superset` chart 0.15.4, a dedicated `superset` node pool, internal-only UI exposure, runtime-created secrets, and checked-in Terraform, Bicep, Helm, and operations guidance.

## Why Superset on AKS is not just another web app

This is the AKS design point to keep in view: **Superset is not a single stateless frontend deployment**.

A useful Superset environment on AKS includes:

- web pods for the UI and REST APIs
- Celery workers for async SQL Lab and background tasks
- a metadata PostgreSQL database for users, dashboards, datasets, saved queries, and schema state
- Redis for cache and Celery transport
- a `superset-init-db` job that upgrades the schema and runs `superset init`
- outbound connectivity to external data engines such as Trino, Spark, Synapse, Snowflake, or PostgreSQL
- runtime secret material for the metadata connection and `SUPERSET_SECRET_KEY`

That is very different from a microservice that can be summarized as `Deployment + Service + external database`.

## What the repo now provides

The Superset workload in this repo is organized around five concrete building blocks:

1. AKS AVM-based Terraform and Bicep wrappers under `workloads/bi/apache-superset/infra`
2. architecture, portal, CLI, and operations guidance under `workloads/bi/apache-superset/docs`
3. Helm values and namespace assets under `workloads/bi/apache-superset/kubernetes`
4. a starter node-pool layout that uses a dedicated `superset` AKS user pool
5. publish-ready blog assets under `blogs/apache-superset`

## Checked-in version contract

These are the repo-backed versions this walkthrough currently matches.

| Component | Checked-in version | Evidence in repo |
| --- | --- | --- |
| Helm chart | `superset/superset` `0.15.4` | `workloads/bi/apache-superset/kubernetes/helm/README.md` |
| Superset runtime | `5.0.0` | `workloads/bi/apache-superset/kubernetes/helm/README.md` and `workloads/bi/apache-superset/kubernetes/helm/superset-values.yaml` |
| Deployment values | `superset-values.yaml` aligned to chart `0.15.4` | `workloads/bi/apache-superset/kubernetes/helm/superset-values.yaml` |

## The target AKS pattern

The blueprint uses these opinions by default:

| Layer | Recommendation | Why |
| --- | --- | --- |
| AKS baseline | Shared AVM wrapper | Keeps cluster creation consistent across workloads |
| Workload placement | Dedicated `superset` node pool with 3 nodes | Isolates BI traffic, Celery workers, and starter stateful dependencies |
| Web tier | 2 Superset web replicas | Keeps the UI available during upgrades |
| Async execution | 2 Celery workers | Separates long-running query work from the web tier |
| Metadata DB | Bundled PostgreSQL | Keeps the starter runnable without extra Azure database setup |
| Cache and queue | Bundled Redis | Makes Celery and cache behavior concrete immediately |
| UI exposure | Internal Azure load balancer | Keeps the UI private by default |

The checked-in values also keep the starter opinionated in useful ways: Celery beat, Flower, and websocket pods stay disabled, the `superset` service account is created up front, and the `superset-init-db` hook job is treated as a first-class rollout dependency.

## Prerequisites and environment contract

Before you start, make sure you have:

- an Azure subscription with AKS quota for a dedicated `superset` node pool
- Azure CLI installed and logged in
- `kubectl` installed
- Helm 3.x installed
- OpenSSL available for local secret generation
- Terraform 1.11+ if you want the Terraform path
- a real admin email address for the first Superset user

The repo-backed CLI path uses this environment contract:

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

## Step 1: Deploy or align the AKS baseline

The repo keeps both IaC options visible because different teams standardize differently.

### Bicep path

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

### Terraform path

```bash
cd workloads/bi/apache-superset/infra/terraform
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform plan
terraform apply
```

Both wrappers create `systempool` plus a dedicated `superset` user pool with the taint `dedicated=superset:NoSchedule` so the web tier, workers, PostgreSQL, and Redis are not competing with unrelated application pods.

## Step 2: Create the namespace, storage class, and runtime secrets

Once AKS is ready, connect to the cluster and create the prerequisites that the chart expects:

```bash
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME"

kubectl apply -f workloads/bi/apache-superset/kubernetes/manifests/namespace.yaml
kubectl apply -f workloads/bi/apache-superset/kubernetes/manifests/managed-csi-premium-storageclass.yaml

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

The storage class step matters because the checked-in PostgreSQL and Redis values expect `managed-csi-premium` for their durable PVCs.

The checked-in values intentionally set `secretEnv.create=false`, so this secret step is part of the reproducible deployment contract rather than an afterthought.

## Step 3: Install Superset with the pinned chart

```bash
helm repo add superset https://apache.github.io/superset
helm repo update

helm upgrade --install superset superset/superset \
  --version "$SUPERSET_HELM_VERSION" \
  --namespace "$SUPERSET_NAMESPACE" \
  --values workloads/bi/apache-superset/kubernetes/helm/superset-values.yaml
```

The values file makes the AKS shape explicit:

- two web replicas for the UI and API tier
- two worker replicas for Celery-backed async execution
- durable PVCs for PostgreSQL and Redis on `managed-csi-premium`
- an internal-only Azure load balancer for the UI
- a reusable `superset` service account for later workload identity wiring

## Step 4: Wait for migrations, create the first admin user, and validate the rollout

Superset is not healthy just because the `superset` service exists. The init hook has to finish and the metadata path has to be ready first.

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

Then validate the parts that actually matter on AKS:

```bash
kubectl get pods -n "$SUPERSET_NAMESPACE"
kubectl get jobs -n "$SUPERSET_NAMESPACE"
kubectl get pvc -n "$SUPERSET_NAMESPACE"
kubectl get storageclass managed-csi-premium
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

## Why init jobs, PVCs, and workers matter on AKS

If you are used to stateless application services, these are the Superset-on-AKS behaviors to internalize early:

1. **`superset-init-db` is part of the rollout contract.** If migrations do not finish, the platform is not healthy yet.
2. **The UI is only one part of the system.** Celery workers, Redis, and PostgreSQL are all operational dependencies.
3. **PVCs matter even in the starter scope.** Metadata state and Redis cache/queue state still need durable backing volumes.
4. **Private access is the safer default.** An internal load balancer makes more sense for a BI surface while credentials are still runtime-created.
5. **The repo should stay secret-free.** Secret keys and admin credentials belong in deployment-time secrets, not in Git.

## Azure integration notes

This starter intentionally keeps Azure dependencies light. It does not wire SSO, Azure Storage, or a managed database by default. That is a scope boundary, not a dead end.

If you extend the design later for exports, cached results, or other Azure Storage-backed flows, keep the same repo rule intact: use workload identity or another managed identity-based approach instead of storage account keys.

## Closing thought

Superset on AKS becomes much easier to reason about when the repo makes the platform shape explicit: web pods, workers, migration jobs, metadata state, cache state, and private operator access.

That is what this blueprint now provides. It is not pretending to be a one-click production platform, but it is a credible AKS starter that a platform team can evolve without throwing away the first implementation.
