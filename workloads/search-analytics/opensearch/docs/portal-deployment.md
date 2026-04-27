# OpenSearch portal deployment path

Use this guide when the team wants to understand or validate the Azure resource shape in the portal before settling into full automation.

## Outcome

You should end with:

- an AKS cluster aligned to the shared AVM baseline
- dedicated node pools for manager and data roles
- an `opensearch` namespace
- Helm releases for manager nodes, data nodes, and Dashboards
- internal operator access to Dashboards and private API access to OpenSearch
- an optional Azure Blob snapshot target wired for managed-identity access instead of storage keys

## Step 1: Review the blueprint assets

Before clicking through the portal, review the implementation artifacts that define the target state:

- architecture: `docs/architecture.md`
- manager Helm values: `kubernetes/helm/manager-values.yaml`
- data Helm values: `kubernetes/helm/data-values.yaml`
- Dashboards Helm values: `kubernetes/helm/dashboards-values.yaml`
- example manifests: `kubernetes/manifests/*.example.yaml`

## Step 2: Create or select the resource group

If you are using the portal-first path, create the resource group up front and then keep its name aligned with the Terraform and Bicep wrappers so the same environment can later be automated without renaming.

Suggested naming:

- resource group: `rg-opensearch-aks-dev`
- cluster: `aks-opensearch-dev`

## Step 3: Create the AKS cluster in the portal

Use the portal to mirror the AVM-oriented design choices:

1. choose the target region
2. enable managed identity
3. enable the OIDC issuer and workload identity features for the cluster
4. enable Azure Monitor integration if your environment expects it
5. keep the cluster API private if that matches your environment constraints
6. create a system pool and then add user pools for `osmgr` and `osdata`

### Suggested pool intent

| Pool | Purpose | Notes |
| --- | --- | --- |
| system/app | cluster add-ons and optional Dashboards | keep OpenSearch data pods off this pool; scale beyond one node before running multiple Dashboards replicas |
| osmgr | cluster-manager pods | start with at least 3 nodes so the default manager replicas can satisfy hard anti-affinity |
| osdata | data and ingest pods | start with at least 3 nodes so the default data replicas can satisfy hard anti-affinity |

If you taint the dedicated pools, keep the taints aligned with the example tolerations in the Helm values.

## Step 4: Prepare snapshot storage access

If you want the checked-in Azure snapshot pattern, keep it keyless from the start:

1. create or select a `StorageV2` account and a private blob container for snapshots
2. disable shared-key access on that storage account
3. create a user-assigned managed identity for OpenSearch snapshots
4. grant that identity `Storage Blob Data Contributor` on the snapshot container
5. add federated credentials on that identity for `system:serviceaccount:opensearch:opensearch-manager-snapshots` and `system:serviceaccount:opensearch:opensearch-data-snapshots`

You can fetch the AKS OIDC issuer URL with:

```bash
az aks show \
  --resource-group rg-opensearch-aks-dev \
  --name aks-opensearch-dev \
  --query oidcIssuerProfile.issuerUrl \
  -o tsv
```

Record the managed identity client ID because the Helm commands below need it.

## Step 5: Connect to the cluster

Once the cluster is provisioned, use Cloud Shell or a local terminal:

```bash
az aks get-credentials \
  --resource-group rg-opensearch-aks-dev \
  --name aks-opensearch-dev
```

## Step 6: Create the storage class, namespace, and secrets

Apply the Premium storage class manifest, then the namespace, and then create real secrets:

```bash
export SNAPSHOT_IDENTITY_CLIENT_ID=<managed-identity-client-id>
export SNAPSHOT_STORAGE_ACCOUNT=<snapshot-storage-account-name>

kubectl apply -f workloads/search-analytics/opensearch/kubernetes/manifests/managed-csi-premium-storageclass.yaml
kubectl apply -f workloads/search-analytics/opensearch/kubernetes/manifests/namespace.yaml
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

Create real secrets instead of applying the example YAML files unchanged.
The storage class manifest matches the AKS built-in `managed-csi-premium` definition, so `kubectl apply` stays safe whether the class already exists or needs to be created.
The snapshot settings secret loads the storage account name into the OpenSearch keystore, which is required because `azure.client.default.account` is a secure setting.
The namespace manifest uses the `privileged` Pod Security profile because the checked-in Helm values enable the chart's sysctl init container to raise `vm.max_map_count` before the OpenSearch JVM starts.

## Step 7: Install OpenSearch and Dashboards

```bash
helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm repo update

helm upgrade --install opensearch-manager opensearch/opensearch \
  --version 3.6.0 \
  --namespace opensearch \
  --set-string "rbac.serviceAccountAnnotations.azure\\.workload\\.identity/client-id=$SNAPSHOT_IDENTITY_CLIENT_ID" \
  --values workloads/search-analytics/opensearch/kubernetes/helm/manager-values.yaml

helm upgrade --install opensearch-data opensearch/opensearch \
  --version 3.6.0 \
  --namespace opensearch \
  --set-string "rbac.serviceAccountAnnotations.azure\\.workload\\.identity/client-id=$SNAPSHOT_IDENTITY_CLIENT_ID" \
  --values workloads/search-analytics/opensearch/kubernetes/helm/data-values.yaml

helm upgrade --install opensearch-dashboards opensearch/opensearch-dashboards \
  --version 3.2.0 \
  --namespace opensearch \
  --values workloads/search-analytics/opensearch/kubernetes/helm/dashboards-values.yaml
```

The checked-in manager and data values install `repository-azure`, load the storage account name from the `opensearch-snapshot-settings` secret into the OpenSearch keystore, enable managed identity token auth, and create workload-identity service accounts when you pass the managed identity client ID with `--set-string`.
Once the pods are ready, use the repository registration example in `docs/operations.md` to create the `azure-managed-identity` snapshot repository.

## Step 8: Validate the deployment

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
- the managed identity client ID available and the Helm releases rendered with the `--set-string` workload identity annotation before repository registration

## Portal-specific review points

- confirm the `osmgr` and `osdata` pools have the expected VM size and disk profile
- confirm the AKS region supports the storage and zoning decisions you chose
- confirm the Dashboards load balancer is internal-only
- confirm shared-key access stays disabled on the snapshot storage account and that the managed identity is scoped to the snapshot container
