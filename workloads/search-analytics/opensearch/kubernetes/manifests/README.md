# OpenSearch manifest overlays

This folder holds small Kubernetes-native assets that sit beside the Helm releases.

## Current contents

- `managed-csi-premium-storageclass.yaml`
- `namespace.yaml`
- `opensearch-admin-credentials.example.yaml`
- `opensearch-dashboards-auth.example.yaml`

Apply the Premium SSD storage class manifest before the Helm releases so the checked-in values can bind their PVCs consistently across AKS clusters, including clusters where AKS already created the built-in `managed-csi-premium` class.
All `.example.yaml` files are templates only. Do not apply them unchanged.
Replace the placeholder secret values before applying them in a real environment. The Helm install commands inject the managed identity client ID onto the manager and data service accounts at deploy time.
