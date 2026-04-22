# Trino portal deployment path

Use this guide when the team wants to validate the Azure resource shape in the portal before switching to the fully scripted path.

## Outcome

You should end with:

- an AKS cluster aligned to the shared AVM baseline
- one dedicated `trino` user pool with 3 nodes
- a `trino` namespace
- a Helm release named `trino` using chart `1.42.1`
- internal-only access to the coordinator service
- a working `tpch` catalog for smoke testing

## Step 1: Review the blueprint assets

Before using the portal, review the checked-in target state:

- architecture: `docs/architecture.md`
- Helm values: `kubernetes/helm/trino-values.yaml`
- namespace manifest: `kubernetes/manifests/namespace.yaml`
- blog package: `../../../blogs/trino`

## Step 2: Create or select the resource group

Suggested naming:

- resource group: `rg-trino-aks-dev`
- cluster: `aks-trino-dev`

Keep those names aligned with the Terraform and Bicep wrappers so the same environment can later move to automation without a rename.

## Step 3: Create the AKS cluster in the portal

Mirror the AVM-oriented design choices when you use the portal:

1. choose the target region
2. enable managed identity
3. enable Azure Monitor integration if your environment expects it
4. keep the cluster API private if that matches your platform standard
5. create a system pool and one user pool named `trino`

### Suggested pool intent

| Pool | Purpose | Notes |
| --- | --- | --- |
| systempool | AKS add-ons | keep Trino pods off this pool |
| trino | coordinator and workers | start with 3 nodes and taint it with `dedicated=trino:NoSchedule` |

If you taint the pool, keep the taint aligned with the tolerations in `trino-values.yaml`.

## Step 4: Connect to the cluster

Once the cluster is provisioned, use Cloud Shell or a local terminal:

```bash
az aks get-credentials --resource-group rg-trino-aks-dev --name aks-trino-dev
```

## Step 5: Create the namespace

```bash
kubectl apply -f workloads/query-engines/trino/kubernetes/manifests/namespace.yaml
```

The starter Trino footprint does not require any bootstrap secret because the checked-in catalog is `tpch` only.

## Step 6: Install Trino

```bash
helm repo add trino https://trinodb.github.io/charts/
helm repo update

helm upgrade --install trino trino/trino --version 1.42.1 --namespace trino --values workloads/query-engines/trino/kubernetes/helm/trino-values.yaml
```

## Step 7: Validate the deployment

```bash
kubectl get deploy,pods,svc -n trino
kubectl port-forward svc/trino 8080:8080 -n trino
curl http://127.0.0.1:8080/v1/info

kubectl exec deploy/trino-coordinator -n trino -- trino --execute "SHOW CATALOGS"

kubectl exec deploy/trino-coordinator -n trino -- trino --execute "SELECT count(*) AS nations FROM tpch.tiny.nation"
```

Check for:

- one healthy coordinator pod
- three healthy worker pods
- the coordinator service staying private inside the cluster
- `tpch` appearing in `SHOW CATALOGS`

## Portal-specific review points

- confirm the `trino` pool has the expected VM size and taint
- confirm the coordinator service is not exposed publicly
- confirm the node count leaves headroom for three workers plus the coordinator
- confirm any future catalog plan for Azure Storage uses workload identity instead of shared keys
