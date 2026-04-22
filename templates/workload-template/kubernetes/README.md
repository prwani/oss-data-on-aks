# Kubernetes assets template

This folder keeps the workload-local Kubernetes assets that sit beside the docs and IaC wrappers.

## Expected structure

- `helm/` for pinned chart values and chart-specific install notes
- `manifests/` for namespace, storage class, CRDs, or other helper manifests that belong in source control

Keep the deployment guides aligned with the exact files stored here. If a workload needs runtime-generated secrets, document how to create them in the deployment guide instead of committing them.
