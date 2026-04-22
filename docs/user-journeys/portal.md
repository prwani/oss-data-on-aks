# Portal-first user journey

Use this shared guide when the team wants to validate Azure resource choices in the portal before it fully commits to repeatable automation. The exact workload steps still live inside each workload folder, but the navigation should feel the same across the repo.

## When this path fits best

Choose the portal-first path when you want to:

- inspect AKS settings visually before standardizing them
- confirm networking, node pools, storage, and monitoring choices with platform stakeholders
- walk through the workload install once before turning it into a scripted path
- compare the final portal shape with the Terraform and Bicep wrappers already checked in

## What to review before opening the portal

Every workload should give you enough context to know what you are trying to build:

| File | What to review |
| --- | --- |
| `README.md` | workload goal, starter topology, and scope |
| `docs/architecture.md` | node pools, storage, service exposure, and AKS-specific constraints |
| `docs/portal-deployment.md` | the exact portal and post-portal steps |
| `docs/operations.md` | validation, upgrade, and runbook expectations |
| `kubernetes/helm` and `kubernetes/manifests` | namespace, storage class, values files, and helper manifests |

Also keep the shared platform docs open:

- [`../platform/architecture.md`](../platform/architecture.md)
- [`../platform/security.md`](../platform/security.md)
- [`../platform/storage.md`](../platform/storage.md)
- [`../platform/observability.md`](../platform/observability.md)

## Standard repo flow

### 1. Review the workload assets first

The portal path still starts in source control. Confirm:

- the intended namespace and release name
- whether the workload needs a dedicated user pool
- whether storage classes, secrets, or operators must exist before install
- whether the checked-in default is internal-only access

### 2. Create or align the resource group and naming

Keep the resource-group and cluster names aligned with the workload wrappers even if you start in the portal. That makes it easier to compare the portal-created environment with the Bicep and Terraform files later.

### 3. Create the AKS cluster in the portal

Mirror the shared AVM-oriented design rather than clicking through arbitrary defaults:

- use managed identity
- keep the system pool small and reserved for add-ons
- add a dedicated user pool for the workload when the blueprint expects one
- enable Azure Monitor or other platform telemetry when your environment requires it
- keep the API surface private or as restricted as your landing zone allows

### 4. Validate workload-specific settings in the portal

Use the portal to confirm the settings that usually matter most in this repo:

| Area | What to inspect |
| --- | --- |
| Node pools | system pool plus dedicated workload pool sizing, VM family, taints, and count |
| Networking | private cluster posture, internal load balancer expectations, VNet/subnet placement |
| Identity | managed identity posture and any Azure role assignments the workload will need later |
| Storage | Premium CSI assumptions, disk SKU, and any storage-class-dependent choices |
| Monitoring | Azure Monitor / Log Analytics alignment and diagnostic settings |

### 5. Connect to AKS and apply the checked-in Kubernetes assets

The portal usually creates the cluster, but workload-local assets still come from this repo:

```bash
az aks get-credentials --resource-group <resource-group> --name <cluster-name>
kubectl apply -f workloads/<category>/<workload>/kubernetes/manifests/namespace.yaml
```

Add any storage-class manifests, secrets, or operator prerequisites described by the workload before installing the chart or manifests.

### 6. Install the workload

The portal guide inside the workload should point to the exact checked-in Helm values or manifest set. Keep that install path aligned with the same release names, namespaces, and assets used by the CLI guide.

### 7. Validate and capture the outcome

Do not stop at “the portal deployment succeeded.” A complete portal walkthrough should finish with:

- `kubectl` checks for pods, services, PVCs, or jobs
- workload-native smoke tests
- confirmation that the access model stayed private unless the docs explicitly say otherwise
- pointers to `docs/operations.md` for day-2 work

### 8. Move the result back into automation

If the team started in the portal, capture any approved deviations in the workload Terraform or Bicep wrapper so the final blueprint does not depend on manual portal memory.

## What good portal docs should cover

A workload's `docs/portal-deployment.md` should tell an operator:

- which Azure resource choices matter for this workload
- which portal defaults to avoid
- what Kubernetes prerequisites must be applied after cluster creation
- how to validate the install without exposing the workload publicly
- what to codify in Terraform or Bicep once the portal experiment is complete
