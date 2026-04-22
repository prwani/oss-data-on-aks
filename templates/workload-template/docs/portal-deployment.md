# `<workload>` portal deployment path

Use this file for the portal-first walkthrough. Even when the operator starts in the portal, the workload docs should still point back to the checked-in Helm values, manifests, and operations notes.

## Outcome

By the end of this guide, an operator should know:

- which AKS shape matches the workload
- which dedicated pool, namespace, and supporting manifests are required
- how to install the workload with the checked-in assets
- how to validate the result before moving to day-2 operations

## Step 1: Review the blueprint assets

Before opening the portal, tell the reader exactly which files define the desired state:

- architecture notes: `docs/architecture.md`
- operations notes: `docs/operations.md`
- Helm values or manifests under `kubernetes/`
- Terraform and Bicep wrappers under `infra/`

## Step 2: Create or align the resource group

Document the naming pattern you want operators to keep consistent with the checked-in wrappers, for example:

- resource group: `rg-<workload>-aks-dev`
- cluster: `aks-<workload>-dev`

## Step 3: Create the AKS cluster in the portal

Mirror the shared AVM-oriented baseline:

1. choose the target region
2. enable managed identity
3. keep a small `systempool`
4. add a dedicated workload pool if the blueprint expects one
5. enable monitoring integrations required by the platform
6. keep the API or workload exposure private unless the architecture notes justify otherwise

## Step 4: Connect to AKS and apply prerequisites

Once the cluster exists, switch to Cloud Shell or a local terminal:

```bash
az aks get-credentials --resource-group rg-<workload>-aks-dev --name aks-<workload>-dev
kubectl apply -f workloads/<category>/<workload>/kubernetes/manifests/namespace.yaml
```

Add any storage-class manifest, secret creation, or operator bootstrap steps here.

## Step 5: Install the workload

Point directly to the checked-in values file or manifest set. Make the release name, namespace, and chart version explicit so the portal guide stays aligned with the CLI guide.

## Step 6: Validate the deployment

List the exact checks operators should run after the install, such as:

- pods, services, PVCs, and jobs in the workload namespace
- workload-native API or CLI smoke tests
- confirmation that the service stayed internal-only by default
- any admin bootstrap or post-install migration steps

## Portal-specific review points

Close with the settings operators should verify visually in the portal, for example:

- node-pool size and VM family
- private networking posture
- managed identity and required RBAC
- storage SKU or disk sizing
- monitoring and diagnostics alignment
