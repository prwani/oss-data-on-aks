# OpenSearch manifest overlays

This folder holds small Kubernetes-native assets that sit beside the Helm releases.

## Current contents

- `managed-csi-premium-storageclass.yaml`
- `namespace.yaml`
- `opensearch-admin-credentials.example.yaml`
- `opensearch-dashboards-auth.example.yaml`

Apply the Premium SSD storage class manifest before the Helm releases so the checked-in values can bind their PVCs consistently across AKS clusters.
The secret manifests are examples only. Replace the placeholder values before applying them in a real environment.
