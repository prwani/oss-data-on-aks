# ClickHouse portal deployment path

Use this guide when the team wants to validate the Azure resource shape in the portal before switching to the fully scripted path.

## Outcome

You should end with:

- an AKS cluster aligned to the shared AVM baseline
- one dedicated `clickhouse` user pool with 3 nodes
- a `clickhouse` namespace and a Premium SSD storage class
- a Helm release named `clickhouse` using chart `9.4.7`
- internal-only access to the ClickHouse service
- a runtime-created admin password secret referenced by the chart

## Step 1: Review the blueprint assets

Before using the portal, review the implementation artifacts:

- architecture: `docs/architecture.md`
- Helm values: `kubernetes/helm/clickhouse-values.yaml`
- storage class manifest: `kubernetes/manifests/managed-csi-premium-storageclass.yaml`
- namespace manifest: `kubernetes/manifests/namespace.yaml`
- blog package: `../../../blogs/clickhouse`

## Step 2: Create or select the resource group

Suggested naming:

- resource group: `rg-clickhouse-aks-dev`
- cluster: `aks-clickhouse-dev`

## Step 3: Create the AKS cluster in the portal

Mirror the AVM-oriented design choices when you use the portal:

1. choose the target region
2. enable managed identity
3. enable Azure Monitor integration if your environment expects it
4. keep the cluster API private if that matches your platform standard
5. create a system pool and one user pool named `clickhouse`

### Suggested pool intent

| Pool | Purpose | Notes |
| --- | --- | --- |
| systempool | AKS add-ons | keep stateful ClickHouse pods off this pool |
| clickhouse | ClickHouse and Keeper | start with 3 nodes and taint it with `dedicated=clickhouse:NoSchedule` |

## Step 4: Connect to the cluster

```bash
az aks get-credentials --resource-group rg-clickhouse-aks-dev --name aks-clickhouse-dev
```

## Step 5: Create the storage class, namespace, and runtime secret

```bash
kubectl apply -f workloads/olap-databases/clickhouse/kubernetes/manifests/managed-csi-premium-storageclass.yaml
kubectl apply -f workloads/olap-databases/clickhouse/kubernetes/manifests/namespace.yaml

kubectl create secret generic clickhouse-auth --namespace clickhouse --from-literal=admin-password="$(openssl rand -base64 32 | tr -d '\n')"
```

The chart values reference `clickhouse-auth` through `auth.existingSecret`, so no password is committed to source control.

## Step 6: Install ClickHouse

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm upgrade --install clickhouse bitnami/clickhouse --version 9.4.7 --namespace clickhouse --values workloads/olap-databases/clickhouse/kubernetes/helm/clickhouse-values.yaml
```

## Step 7: Validate the deployment

```bash
kubectl get statefulset,pods,pvc,svc -n clickhouse
```

Then validate the service privately:

```bash
export CLICKHOUSE_PASSWORD=$(kubectl get secret clickhouse-auth -n clickhouse -o jsonpath='{.data.admin-password}' | base64 --decode)

kubectl port-forward svc/clickhouse 8123:8123 9000:9000 -n clickhouse
curl http://127.0.0.1:8123/ping
curl --user default:$CLICKHOUSE_PASSWORD "http://127.0.0.1:8123/?query=SELECT%20version()"
```

Check for:

- all ClickHouse and Keeper pods healthy
- every PVC in the namespace bound
- no public service exposure for ClickHouse
- shard and replica layout visible through `system.clusters`

## Portal-specific review points

- confirm the `clickhouse` pool has the expected VM size, taint, and disk profile
- confirm the Premium SSD storage class is present before the Helm install
- confirm Keeper has quorum during upgrade or restart testing
- confirm any future backup or data-lake integration uses managed identity rather than storage keys
