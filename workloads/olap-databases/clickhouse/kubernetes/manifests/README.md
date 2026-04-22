# ClickHouse manifest overlays

This folder holds small Kubernetes-native assets that sit beside the Helm release.

## Current contents

- `managed-csi-premium-storageclass.yaml`
- `namespace.yaml`

The ClickHouse chart uses `auth.existingSecret`, so the admin password is created at runtime with `kubectl create secret generic clickhouse-auth ...` instead of being committed to source control.
