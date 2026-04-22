# `<workload>` manifest overlays

Use this folder for small Kubernetes-native assets that should stay in source control beside the workload docs.

## Typical contents

- `namespace.yaml`
- storage-class manifests when the workload needs a predictable class name
- CRDs or helper manifests that must exist before the main install

Keep runtime-generated secrets out of this folder. Document those in the workload deployment guide instead.
