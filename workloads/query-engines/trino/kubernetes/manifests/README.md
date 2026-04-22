# Trino manifest overlays

This folder holds small Kubernetes-native assets that sit beside the Helm release.

## Current contents

- `namespace.yaml`

The Trino starter blueprint does not ship a secret manifest because the checked-in catalog is `tpch` only. When you add external catalogs, create environment-specific service accounts, secrets, or workload identity bindings outside the checked-in default path.
