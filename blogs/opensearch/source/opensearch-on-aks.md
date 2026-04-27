# Deploying OpenSearch on AKS with AKS AVM, Helm, and internal Dashboards

**Publication target:** Microsoft TechCommunity > Azure > Linux and Open Source Blog

## Summary

OpenSearch is easy to demo on Kubernetes, but getting to a reusable Azure-first deployment pattern takes a little more discipline. In this post, I will walk through a starter blueprint for running OpenSearch on Azure Kubernetes Service (AKS) with an AKS Azure Verified Modules (AVM) baseline, separate Helm releases for manager and data nodes, and an internal-only access pattern for Dashboards and the OpenSearch API.

The goal is not to claim a one-click production deployment. The goal is to create a clean, repeatable foundation that platform teams can evolve into a production-ready operating model without starting from a throwaway lab.

## Why OpenSearch on AKS is worth standardizing

OpenSearch is a strong fit when teams want a Kubernetes-native search and analytics platform but still want Azure-native control around:

- cluster creation
- managed identity and networking
- storage choices
- operational visibility
- internal versus external access

The challenge is that OpenSearch is not just another stateless app. It has persistent shard storage, JVM heap requirements, disk pressure behavior, cluster elections, recovery flows, and backup expectations. So a reusable AKS pattern needs to cover more than `helm install`.

## Why this is not a typical AKS microservice

This is the part I want readers to notice early: **OpenSearch on AKS is not a normal stateless microservice deployment**.

Typical AKS microservices often look like this:

- a `Deployment`
- replicas that can restart almost anywhere
- little or no persistent per-pod storage
- durable state kept in some other service

OpenSearch is different:

- manager and data tiers run as **StatefulSets**
- each **manager pod needs its own disk** for cluster metadata durability
- each **data pod needs its own disk** for shard storage, relocation, and recovery
- a missing or unbound **PersistentVolumeClaim (PVC)** will block pod startup

That is why OpenSearch validation on AKS must include `kubectl get pvc`, not just `kubectl get pods`.

## OpenSearch architecture before the AKS mapping

These official diagrams are helpful because they explain the underlying OpenSearch model before I add the Azure and AKS-specific choices.

![Official OpenSearch cluster architecture](../assets/opensearch-cluster.png)

*Source: [OpenSearch documentation cluster architecture diagram](https://docs.opensearch.org/latest/images/cluster.png), OpenSearch Contributors, Apache License 2.0.*

![Official OpenSearch shard and replica architecture](../assets/opensearch-cluster-replicas.png)

*Source: [OpenSearch documentation shard and replica diagram](https://docs.opensearch.org/latest/images/intro/cluster-replicas.png), OpenSearch Contributors, Apache License 2.0.*

## What this repo now provides

The OpenSearch workload in the repo is organized around five practical building blocks:

1. a shared AKS baseline under `platform/aks-avm`
2. workload wrappers for Terraform and Bicep under `workloads/search-analytics/opensearch/infra`
3. deployment guidance for portal-first and CLI-first operators under `workloads/search-analytics/opensearch/docs`
4. Helm values and Kubernetes manifests under `workloads/search-analytics/opensearch/kubernetes`
5. publish-ready blog assets under `blogs/opensearch`

That split is intentional. It keeps AKS platform concerns reusable while still letting the workload carry its own installation and operational guidance.

## Checked-in version contract

These are the repo-backed versions this walkthrough currently matches.

| Component | Checked-in version | Evidence in repo |
| --- | --- | --- |
| Manager and data charts | `opensearch/opensearch` `3.6.0` | `workloads/search-analytics/opensearch/kubernetes/helm/README.md` |
| Dashboards chart | `opensearch/opensearch-dashboards` `3.2.0` | `workloads/search-analytics/opensearch/kubernetes/helm/README.md` |

The checked-in values intentionally inherit runtime images from those chart defaults, so the chart version is the most concrete repo-backed contract to revalidate before publication.


## The target architecture

For the first opinionated OpenSearch blueprint in this repo, I am using this starting pattern:

![Combined OpenSearch-on-AKS architecture](../assets/opensearch-on-aks-combined-architecture.svg)

*Custom AKS mapping for this repository. It combines OpenSearch cluster roles, shard/replica behavior, dedicated AKS node pools, StatefulSets, and per-pod PVC-backed Azure Disks.*

The secure portal deployment keeps the same OpenSearch topology but adds a private AKS control plane and runs the Azure deployment script inside the VNet so the portal flow can still install the Kubernetes and Helm resources:

![Secure OpenSearch-on-AKS architecture](../assets/opensearch-on-aks-secure-architecture.svg)

*Secure deployment mapping using Microsoft Azure Architecture Icons. It highlights the private AKS API, deployment script subnet, internal Dashboards load balancer, workload identity to Blob snapshots, and encrypted persistent disks.*

| Layer | Recommendation | Why |
| --- | --- | --- |
| AKS baseline | Shared AVM wrapper | Keeps cluster creation consistent across workloads |
| Manager tier | Dedicated Helm release | Protects elections and cluster metadata |
| Data tier | Dedicated Helm release | Isolates shard-heavy indexing and storage I/O |
| OpenSearch API | `ClusterIP` only | Reduces exposure of the core service |
| Dashboards | Internal Azure load balancer | Gives operators access without making the API public |
| Persistent storage | Azure Disk CSI Premium SSD | Good default for durable stateful workloads |
| Snapshots | Azure Blob Storage | Provides an external recovery target |

The standard Helm release names in the blueprint are:

- `opensearch-manager`
- `opensearch-data`
- `opensearch-dashboards`

This matters because the Helm values and service discovery examples assume those names.

## Prerequisites

Before you start, make sure you have:

- an Azure subscription with AKS and managed disk quota
- Azure CLI installed and logged in
- `kubectl` installed
- Helm 3.x installed
- Terraform 1.11+ if you want the Terraform path
- a globally unique storage account name if you want to create snapshot storage from the example wrappers

## Pick your deployment experience

If you want the Azure portal to run the full seven-step standard flow, use this button:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fprwani%2Foss-data-on-aks%2Fmain%2Fworkloads%2Fsearch-analytics%2Fopensearch%2Finfra%2Fportal%2Fazuredeploy-full.json)

The full portal deployment asks for an admin password, creates the AKS cluster, dedicated node pools, snapshot storage account, managed identity, and federated credentials, then uses an Azure deployment script to run the Kubernetes namespace, secret, Helm, readiness, and snapshot repository steps. The password is passed to the deployment script as a secure parameter and is used to create the OpenSearch and Dashboards Kubernetes secrets.

For a private AKS control plane, use the secure portal deployment:

[![Deploy to Azure (secure)](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fprwani%2Foss-data-on-aks%2Fmain%2Fworkloads%2Fsearch-analytics%2Fopensearch%2Finfra%2Fportal%2Fazuredeploy-secure.json)

The secure template creates a VNet, places AKS nodes in a private subnet, disables public AKS API access, and runs the installation script from an Azure Container Instances subnet inside the same VNet so `kubectl` and Helm can reach the private API server.

If you only want the Azure baseline and prefer to run the Kubernetes and Helm steps yourself, use the baseline template at `workloads/search-analytics/opensearch/infra/portal/azuredeploy.json` instead.

If you want one command to run the full workflow, use the helper script. It asks for the deployment engine, resource group, region, cluster name, storage account, and admin password, then runs the Azure deployment plus the Kubernetes, Helm, validation, and snapshot repository steps:

```bash
workloads/search-analytics/opensearch/scripts/az-cli/deploy.sh
```

## Step 1: Deploy or align the AKS baseline

This repo keeps both IaC options visible because different teams standardize differently.

### Bicep path

```bash
export LOCATION=swedencentral
export RESOURCE_GROUP=rg-opensearch-aks-dev
export CLUSTER_NAME=aks-opensearch-dev
export SNAPSHOT_STORAGE_ACCOUNT=opssnapdev001

az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file workloads/search-analytics/opensearch/infra/bicep/main.bicep \
  --parameters \
      clusterName="$CLUSTER_NAME" \
      location="$LOCATION" \
      snapshotStorageAccountName="$SNAPSHOT_STORAGE_ACCOUNT"
```

### Terraform path

```bash
cd workloads/search-analytics/opensearch/infra/terraform
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars for your resource group, region, cluster name,
# and globally unique snapshot storage account name.

terraform init
terraform plan
terraform apply
```

The current wrappers focus on the AKS baseline and a starter snapshot storage account. They are designed to be a strong repo contract, not a claim that every day-2 detail is already automated.
When snapshot storage is enabled, the wrappers also turn on the AKS OIDC issuer and workload identity features, create a user-assigned managed identity plus federated credentials for the OpenSearch snapshot service accounts, and disable shared-key access on the starter storage account.
The checked-in wrappers provision `systempool`, `osmgr`, and `osdata`. The dedicated `osmgr` and `osdata` pools start with three nodes each so the default manager and data replicas can satisfy their hard anti-affinity rules.

## Step 2: Connect to AKS and create the namespace

Once the cluster is ready, connect to it and create the dedicated namespace:

```bash
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME"

kubectl apply -f workloads/search-analytics/opensearch/kubernetes/manifests/managed-csi-premium-storageclass.yaml
kubectl apply -f workloads/search-analytics/opensearch/kubernetes/manifests/namespace.yaml
```

If you kept snapshot storage enabled, capture the snapshot managed identity client ID from your deployment outputs because the Helm install uses it to annotate the workload-identity service accounts.

## Step 3: Create the bootstrap secrets

The blueprint ships example secret manifests for:

- the initial OpenSearch admin password
- the Dashboards username, password, and cookie secret
- the snapshot storage account name that the Azure repository plugin loads into the OpenSearch keystore

Treat those YAML files as templates only. Create real secrets instead of applying the example manifests unchanged:

```bash
kubectl create secret generic opensearch-admin-credentials \
  --namespace opensearch \
  --from-literal=password='<strong-admin-password>' \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic opensearch-dashboards-auth \
  --namespace opensearch \
  --from-literal=username='admin' \
  --from-literal=password='<strong-admin-password>' \
  --from-literal=cookie='<32-character-cookie-secret>' \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic opensearch-snapshot-settings \
  --namespace opensearch \
  --from-literal=azure.client.default.account="$SNAPSHOT_STORAGE_ACCOUNT" \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Step 4: Install the manager tier

This blueprint uses a separate release for manager nodes. The surrounding docs use cluster-manager language, but the current Helm chart still uses `masterService` and `master` role naming in its values.

```bash
export OPENSEARCH_HELM_VERSION=3.6.0
export OPENSEARCH_DASHBOARDS_HELM_VERSION=3.2.0
export SNAPSHOT_IDENTITY_CLIENT_ID=<snapshot-managed-identity-client-id>

helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm repo update

helm upgrade --install opensearch-manager opensearch/opensearch \
  --version "$OPENSEARCH_HELM_VERSION" \
  --namespace opensearch \
  --set-string "rbac.serviceAccountAnnotations.azure\\.workload\\.identity/client-id=$SNAPSHOT_IDENTITY_CLIENT_ID" \
  --values workloads/search-analytics/opensearch/kubernetes/helm/manager-values.yaml
```

The manager values focus on:

- three manager replicas
- Premium SSD-backed PVCs
- hard anti-affinity
- optional node-pool targeting for an `osmgr` AKS pool
- `repository-azure` plus `azure.client.default.token_credential_type: managed_identity` for the keyless snapshot path

## Step 5: Install the data tier

The data release joins the same cluster and points back to the manager service for discovery:

```bash
helm upgrade --install opensearch-data opensearch/opensearch \
  --version "$OPENSEARCH_HELM_VERSION" \
  --namespace opensearch \
  --set-string "rbac.serviceAccountAnnotations.azure\\.workload\\.identity/client-id=$SNAPSHOT_IDENTITY_CLIENT_ID" \
  --values workloads/search-analytics/opensearch/kubernetes/helm/data-values.yaml
```

The data values raise storage and JVM sizing relative to the manager tier and are intended for a dedicated `osdata` node pool.

## Step 6: Install Dashboards with internal-only exposure

```bash
helm upgrade --install opensearch-dashboards opensearch/opensearch-dashboards \
  --version "$OPENSEARCH_DASHBOARDS_HELM_VERSION" \
  --namespace opensearch \
  --values workloads/search-analytics/opensearch/kubernetes/helm/dashboards-values.yaml
```

The Dashboards values do two important things:

1. they point Dashboards at the internal OpenSearch service
2. they configure the service as an **internal** Azure load balancer

That is a much better default than exposing the OpenSearch API publicly.

To find the internal Dashboards URL, check the service after Azure assigns the private load balancer IP:

```bash
kubectl get svc opensearch-dashboards -n opensearch
```

Use the private address shown in the service's `EXTERNAL-IP` column. Do not use the `CLUSTER-IP`; that address is only reachable from inside the Kubernetes cluster.

From a network path that can reach the AKS virtual network, open `http://<dashboards-internal-ip>:5601`. If you are testing from your workstation and do not have private network connectivity to that internal IP, use port-forward instead:

```bash
kubectl port-forward svc/opensearch-dashboards 5601:5601 -n opensearch
```

Then open `http://127.0.0.1:5601`.

The default username in this walkthrough is `admin`. The password is the same value you used for `<strong-admin-password>` when creating both `opensearch-admin-credentials` and `opensearch-dashboards-auth` in Step 3.

## Step 7: Validate the deployment

At minimum, validate the pod set, PVC bindings, and service shape:

```bash
kubectl get pods -n opensearch
kubectl get pvc -n opensearch
kubectl get svc -n opensearch
kubectl describe svc opensearch-dashboards -n opensearch
```

For this workload, the PVC check is not just nice to have. The manager and data pods each depend on their own Azure Disk-backed PVC, so `kubectl get pvc` needs to show every claim as `Bound` before you can trust the rollout.

For API validation without public exposure, use port-forward:

```bash
kubectl port-forward svc/opensearch-manager 9200:9200 -n opensearch
curl -k https://127.0.0.1:9200
```

If you deployed the starter snapshot storage path, register and verify the Azure Blob repository after the cluster is healthy:

```bash
export SNAPSHOT_CONTAINER=opensearch-snapshots

curl -k -u "admin:<your-admin-password>" \
  -XPUT https://127.0.0.1:9200/_snapshot/azure-managed-identity \
  -H 'Content-Type: application/json' \
  -d "{\"type\":\"azure\",\"settings\":{\"client\":\"default\",\"container\":\"$SNAPSHOT_CONTAINER\"}}"

curl -k -u "admin:<your-admin-password>" \
  -XPOST https://127.0.0.1:9200/_snapshot/azure-managed-identity/_verify?pretty
```

## Why I like this starting pattern

It gives teams a cleaner path than an all-in-one Helm demo:

- cluster creation is tied back to a shared AVM baseline
- manager and data responsibilities are separated early
- storage and access choices are visible in source control
- the same repo supports portal-first and CLI-first operators
- the implementation assets are close enough to the blog content that they can evolve together

## Try a few OpenSearch API calls

The OpenSearch documentation has a good [Search data](https://docs.opensearch.org/latest/getting-started/search-data/) walkthrough that introduces query string queries and Query DSL. After the AKS deployment is healthy, you can run the same style of examples against your cluster through the port-forwarded manager service.

First, load a small sample data set:

```bash
kubectl port-forward svc/opensearch-manager 9200:9200 -n opensearch

curl -k -u "admin:<your-admin-password>" \
  -XDELETE https://127.0.0.1:9200/students

curl -k -u "admin:<your-admin-password>" \
  -XPOST "https://127.0.0.1:9200/_bulk?refresh=true" \
  -H 'Content-Type: application/x-ndjson' \
  --data-binary @- <<'EOF'
{ "create": { "_index": "students", "_id": "1" } }
{ "name": "John Doe", "gpa": 3.89, "grad_year": 2022}
{ "create": { "_index": "students", "_id": "2" } }
{ "name": "Jonathan Powers", "gpa": 3.85, "grad_year": 2025 }
{ "create": { "_index": "students", "_id": "3" } }
{ "name": "Jane Doe", "gpa": 3.52, "grad_year": 2024 }
EOF
```

Then try a few searches:

```bash
# Retrieve all documents.
curl -k -u "admin:<your-admin-password>" \
  https://127.0.0.1:9200/students/_search?pretty

# Use a query string query.
curl -k -u "admin:<your-admin-password>" \
  "https://127.0.0.1:9200/students/_search?q=name:john&pretty"

# Use Query DSL full-text search.
curl -k -u "admin:<your-admin-password>" \
  -XGET https://127.0.0.1:9200/students/_search?pretty \
  -H 'Content-Type: application/json' \
  -d '{"query":{"match":{"name":"doe john"}}}'

# Use exact-value and range filters.
curl -k -u "admin:<your-admin-password>" \
  -XGET https://127.0.0.1:9200/students/_search?pretty \
  -H 'Content-Type: application/json' \
  -d '{"query":{"bool":{"must":[{"match":{"name":"doe"}},{"range":{"gpa":{"gte":3.6,"lte":3.9}}},{"term":{"grad_year":2022}}]}}}'
```

Those examples are intentionally small, but they prove that indexing, search, full-text analysis, exact filters, and range filters are working through the internal OpenSearch API. After you have data in the cluster, use the [OpenSearch Dashboards quickstart](https://docs.opensearch.org/latest/dashboards/quickstart/) to explore it visually in Dashboards.

## What comes next

This first post gets OpenSearch running on AKS with a cleaner Azure-first blueprint. The next question is what changes when the workload needs to behave like a durable platform rather than a demo.

That is the focus of Part 2: dedicated node pools, disk headroom, private access, snapshots, observability, and day-2 operations.
