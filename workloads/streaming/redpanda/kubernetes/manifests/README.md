# Redpanda manifest overlays

This folder holds small Kubernetes-native assets that sit beside the Helm release.

## Current contents

- `managed-csi-premium-storageclass.yaml`
- `namespace.yaml`

Apply the Premium SSD storage class and namespace manifest before the Helm release. The namespace uses privileged Pod Security labels because the checked-in Redpanda values keep `tuning.tune_aio_events` enabled, and that tuning path creates a privileged container.

This blueprint intentionally does not check in sample secret YAMLs. If you enable SASL, bring your own TLS material, or later configure tiered storage, create those secrets outside the repo with `kubectl create secret`, External Secrets, or another secret delivery system.
