# `az` CLI-first user journey

Use this shared guide to navigate any workload's automation-first path. The workload folders keep the exact commands, but the overall flow is intentionally consistent across the repository.

## When to use this path

Choose the `az` CLI path when your team wants:

- repeatable steps from day one
- source-controlled Terraform or Bicep wrappers
- command-line validation of AKS, Helm, and Kubernetes assets
- a clean handoff to pipelines or helper scripts later

If the team wants to explore the shape of the environment first, start with the shared [portal-first guide](./portal.md) and then return here.

## Shared prerequisites

| Tool or access | Why it is needed |
| --- | --- |
| Azure CLI | login, subscription selection, resource-group creation, and `az aks get-credentials` |
| `kubectl` | namespace setup, secret creation, rollout checks, and workload validation |
| Helm 3.x or workload-specific CLI | chart installs, upgrades, or operator setup |
| Terraform 1.11+ | only if the workload keeps the Terraform wrapper path |
| Access to this repo | the workload docs, manifests, and values files are the source of truth |

## How to read any workload folder

Before you run commands, review these files in the target workload:

| File | Why it matters |
| --- | --- |
| `README.md` | summarizes the workload goal, starter topology, and scope |
| `docs/architecture.md` | explains why the workload needs a specific AKS design |
| `docs/az-cli-deployment.md` | contains the exact workload commands |
| `docs/operations.md` | captures day-2 checks, upgrades, and runbooks |
| `infra/terraform` and `infra/bicep` | define the cluster shape that extends the shared AKS baseline |
| `kubernetes/helm` and `kubernetes/manifests` | pin the workload-local values and helper manifests |
| `scripts/az-cli` | optional helper area for wrappers that stay aligned with the docs |

## Standard repo flow

### 1. Choose the workload and review shared guidance

Start with:

- [`../platform/architecture.md`](../platform/architecture.md)
- [`../platform/security.md`](../platform/security.md)
- [`../platform/storage.md`](../platform/storage.md)
- [`../platform/observability.md`](../platform/observability.md)

Then move into the workload-specific `README.md` and `docs/az-cli-deployment.md`.

### 2. Set environment variables

Most workload guides use the same small set of shell variables:

```bash
export LOCATION=eastus
export RESOURCE_GROUP=rg-<workload>-aks-dev
export CLUSTER_NAME=aks-<workload>-dev
export NAMESPACE=<workload>
```

Add workload-specific values such as chart versions, admin usernames, or pool names in the workload guide rather than inventing a different structure for every blueprint.

### 3. Pick Bicep or Terraform for the AKS baseline

The checked-in workload docs should offer both paths:

```bash
# Bicep
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file workloads/<category>/<workload>/infra/bicep/main.bicep \
  --parameters clusterName="$CLUSTER_NAME" location="$LOCATION"
```

```bash
# Terraform
cd workloads/<category>/<workload>/infra/terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

Whichever path you use, the cluster shape should stay aligned with the shared AVM baseline and the workload docs.

### 4. Connect to AKS

```bash
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME"
```

The workload guide should then show the namespace, storage-class, or secret prerequisites that must be applied before the main install.

### 5. Apply workload prerequisites

Common examples across the repo:

- namespace manifests
- storage-class manifests for durable stateful workloads
- runtime-generated Kubernetes secrets
- operator CRDs or supporting controllers

Keep those steps in `docs/az-cli-deployment.md` and mirror the checked-in assets under `kubernetes/manifests`.

### 6. Install and validate the workload

The install section should point directly to the pinned chart values or manifests and finish with runnable validation commands, such as:

- `kubectl get pods,svc -n <namespace>`
- workload-native smoke tests
- port-forward or internal-only access checks
- PVC, StatefulSet, or job status where applicable

### 7. Capture the day-2 follow-up

After the first successful install, operators should know where to find:

- upgrade guidance
- scale-out or retention notes
- backup or restore expectations
- helper scripts or diagnostics

That content belongs in `docs/operations.md` and, when useful, `scripts/az-cli/README.md`.

## Common adaptation points

| Topic | Shared default | Where to specialize |
| --- | --- | --- |
| Service exposure | `ClusterIP` or private-only access | workload deployment guide and Helm values |
| Secrets | generate or inject at deploy time | workload docs, never checked-in values |
| Dedicated pool naming | one workload-oriented user pool | Terraform/Bicep wrappers and chart tolerations |
| Storage class | Premium CSI where durable disks matter | manifests and architecture docs |
| Azure integrations | workload identity or managed identity | security guidance plus workload-specific notes |

## Exit criteria for a good CLI guide

A workload's `docs/az-cli-deployment.md` should be considered complete when it lets an operator:

1. deploy the AKS baseline with Bicep or Terraform
2. prepare the namespace, storage, and secrets safely
3. install the workload with checked-in values or manifests
4. validate the result without guessing
5. find the next operational steps in `docs/operations.md`
