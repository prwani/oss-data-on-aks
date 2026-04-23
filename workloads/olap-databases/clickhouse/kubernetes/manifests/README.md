# ClickHouse manifest overlays

This folder holds small Kubernetes-native assets that sit beside the Helm release.

## Current contents

- `managed-csi-premium-storageclass.yaml`
- `namespace.yaml`

The storage class manifest intentionally matches the AKS built-in `managed-csi-premium` class so `kubectl apply` can create it on fresh clusters or patch it safely when the class already exists.

The ClickHouse chart uses `auth.existingSecret`, so the admin password is created at runtime with `kubectl create secret generic clickhouse-auth ...` instead of being committed to source control.
