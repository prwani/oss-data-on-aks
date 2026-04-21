# OpenSearch `az` CLI deployment path

Use this guide for the automation-first path.

## Suggested flow

1. Authenticate with `az` and select the target subscription.
2. Create the resource group.
3. Deploy the shared AKS baseline with either:
   - `platform/aks-avm/terraform`
   - `platform/aks-avm/bicep`
4. Connect with `az aks get-credentials`.
5. Install OpenSearch via the chosen chart or manifests.
6. Validate the cluster, storage bindings, and access path.

## Implementation notes

- keep the OpenSearch API internal by default
- prefer a dedicated namespace
- document every Helm values override in source control

