# Trino manifest overlays

This folder holds small Kubernetes-native assets that sit beside the Helm release.

## Current contents

- `namespace.yaml`

The Trino starter blueprint does not ship a secret manifest because the checked-in source catalog is generated `tpcds`. When you enable the Iceberg REST catalog on ADLS Gen2, create environment-specific service accounts, secrets, or workload identity bindings outside the checked-in default path.
