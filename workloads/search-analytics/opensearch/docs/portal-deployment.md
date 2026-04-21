# OpenSearch portal deployment path

Use this guide when the team wants to understand or validate the Azure resource shape in the portal before settling into full automation.

## Outcome

You should end with:

- an AKS cluster aligned to the shared AVM baseline
- dedicated node pools for manager and data roles
- an `opensearch` namespace
- Helm releases for manager nodes, data nodes, and Dashboards
- internal operator access to Dashboards and private API access to OpenSearch

## Step 1: Review the blueprint assets

Before clicking through the portal, review the implementation artifacts that define the target state:

- architecture: `docs/architecture.md`
- manager Helm values: `kubernetes/helm/manager-values.yaml`
- data Helm values: `kubernetes/helm/data-values.yaml`
- Dashboards Helm values: `kubernetes/helm/dashboards-values.yaml`
- example secrets: `kubernetes/manifests/*.example.yaml`

## Step 2: Create or select the resource group

If you are using the portal-first path, create the resource group up front and then keep its name aligned with the Terraform and Bicep wrappers so the same environment can later be automated without renaming.

Suggested naming:

- resource group: `rg-opensearch-aks-dev`
- cluster: `aks-opensearch-dev`

## Step 3: Create the AKS cluster in the portal

Use the portal to mirror the AVM-oriented design choices:

1. choose the target region
2. enable managed identity
3. enable Azure Monitor integration if your environment expects it
4. keep the cluster API private if that matches your environment constraints
5. create a system pool and then add user pools for `osmgr` and `osdata`

### Suggested pool intent

| Pool | Purpose | Notes |
| --- | --- | --- |
| system/app | cluster add-ons and optional Dashboards | keep OpenSearch data pods off this pool |
| osmgr | cluster-manager pods | smaller, steady capacity |
| osdata | data and ingest pods | larger disks and stronger throughput profile |

If you taint the dedicated pools, keep the taints aligned with the example tolerations in the Helm values.

## Step 4: Connect to the cluster

Once the cluster is provisioned, use Cloud Shell or a local terminal:

```bash
az aks get-credentials \
  --resource-group rg-opensearch-aks-dev \
  --name aks-opensearch-dev
```

## Step 5: Create the namespace and secrets

Apply the namespace and then create real secrets from the example manifests:

```bash
kubectl apply -f workloads/search-analytics/opensearch/kubernetes/manifests/namespace.yaml
kubectl apply -f workloads/search-analytics/opensearch/kubernetes/manifests/opensearch-admin-credentials.example.yaml
kubectl apply -f workloads/search-analytics/opensearch/kubernetes/manifests/opensearch-dashboards-auth.example.yaml
```

Replace the placeholder values before applying the secrets in a real environment.

## Step 6: Install OpenSearch and Dashboards

```bash
helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm repo update

helm upgrade --install opensearch-manager opensearch/opensearch \
  --namespace opensearch \
  --values workloads/search-analytics/opensearch/kubernetes/helm/manager-values.yaml

helm upgrade --install opensearch-data opensearch/opensearch \
  --namespace opensearch \
  --values workloads/search-analytics/opensearch/kubernetes/helm/data-values.yaml

helm upgrade --install opensearch-dashboards opensearch/opensearch-dashboards \
  --namespace opensearch \
  --values workloads/search-analytics/opensearch/kubernetes/helm/dashboards-values.yaml
```

## Step 7: Validate the deployment

```bash
kubectl get pods -n opensearch
kubectl get pvc -n opensearch
kubectl get svc -n opensearch
```

Check for:

- manager pods scheduled and healthy
- data pods bound to persistent volumes
- Dashboards service receiving an internal IP
- no unintended public endpoint for the OpenSearch API

## Portal-specific review points

- confirm the `osmgr` and `osdata` pools have the expected VM size and disk profile
- confirm the AKS region supports the storage and zoning decisions you chose
- confirm the Dashboards load balancer is internal-only
- confirm the snapshot storage account plan before production rollout
