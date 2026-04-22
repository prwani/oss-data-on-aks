# Redpanda portal deployment path

Use this guide when the team wants to validate the Azure resource shape in the portal before settling into full automation.

## Outcome

You should end with:

- an AKS cluster aligned to the shared AVM baseline
- a `systempool` for add-ons and a dedicated `rpbroker` pool with 3 nodes
- cert-manager installed for chart-managed TLS
- a `redpanda` namespace with the right Pod Security labels
- a three-broker Redpanda cluster deployed from the pinned Helm values
- internal-only listener exposure by default

## Step 1: Review the blueprint assets

Before clicking through the portal, review the implementation artifacts that define the target state:

- architecture: `docs/architecture.md`
- Helm values: `kubernetes/helm/redpanda-values.yaml`
- storage class: `kubernetes/manifests/managed-csi-premium-storageclass.yaml`
- namespace: `kubernetes/manifests/namespace.yaml`

## Step 2: Create or select the resource group

If you are taking the portal-first path, create the resource group up front and keep its name aligned with the Terraform and Bicep wrappers so the same environment can later be automated without renaming.

Suggested naming:

- resource group: `rg-redpanda-aks-dev`
- cluster: `aks-redpanda-dev`

## Step 3: Create the AKS cluster in the portal

Use the portal to mirror the AVM-oriented design choices:

1. choose the target region
2. enable managed identity
3. keep the Azure Disk CSI driver enabled
4. keep the API private if that matches your environment constraints
5. create the `systempool`
6. add the dedicated `rpbroker` user pool

### Suggested pool intent

| Pool | Purpose | Starter shape |
| --- | --- | --- |
| `systempool` | AKS add-ons, cert-manager, Helm jobs | `1 x Standard_D4ds_v5` |
| `rpbroker` | Redpanda brokers only | `3 x Standard_D8ds_v5` |

Use an x86_64 VM family that exposes **SSE4.2** on the broker pool. The `Standard_D8ds_v5` default in the repo is a concrete starter choice. If you change the pool name or taint, update `kubernetes/helm/redpanda-values.yaml` so the node selector and toleration stay aligned.

For the `rpbroker` pool, add this taint:

```text
dedicated=redpanda-broker:NoSchedule
```

If the region supports availability zones and your deployment target needs stronger fault isolation, spread the `rpbroker` nodes across zones and revisit `rackAwareness.enabled` later.

## Step 4: Connect to the cluster

Once the cluster is provisioned, use Cloud Shell or a local terminal:

```bash
az aks get-credentials \
  --resource-group rg-redpanda-aks-dev \
  --name aks-redpanda-dev
```

## Step 5: Install cert-manager

The checked-in Helm values leave Redpanda TLS enabled, so install cert-manager before the Helm release:

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.17.2/cert-manager.yaml

kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-webhook -n cert-manager
```

## Step 6: Create the storage class and namespace

Apply the Premium SSD storage class and then the namespace:

```bash
kubectl apply -f workloads/streaming/redpanda/kubernetes/manifests/managed-csi-premium-storageclass.yaml
kubectl apply -f workloads/streaming/redpanda/kubernetes/manifests/namespace.yaml
```

The namespace uses the `privileged` Pod Security profile because the checked-in values keep `tuning.tune_aio_events` enabled, and that tuning path creates a privileged container.

## Step 7: Install Redpanda

```bash
helm repo add redpanda https://charts.redpanda.com
helm repo update

helm upgrade --install redpanda redpanda/redpanda \
  --version 26.1.1 \
  --namespace redpanda \
  --values workloads/streaming/redpanda/kubernetes/helm/redpanda-values.yaml

kubectl rollout status statefulset/redpanda -n redpanda --timeout=15m
```

## Step 8: Validate the deployment

```bash
kubectl get pods -n redpanda -o wide
kubectl get pvc -n redpanda
kubectl get certificates -n redpanda
kubectl get svc -n redpanda
```

Check for:

- three broker pods running on `rpbroker` nodes
- every PVC in the `Bound` state
- cert-manager certificates becoming `Ready`
- no unintended external service exposure

For a quick admin API readiness check without enabling external listeners:

```bash
kubectl port-forward svc/redpanda 9644:9644 -n redpanda
curl -sk https://127.0.0.1:9644/v1/status/ready
```

## Portal-specific review points

- confirm the `rpbroker` pool still has three schedulable nodes after any autoscaling choices
- confirm the broker VM family is x86_64 and SSE4.2-capable
- confirm the storage class is backed by Premium SSD
- confirm the Redpanda services do not receive public IPs
- confirm external listener and tiered-storage decisions stay outside the default install until the network and identity plan is ready
