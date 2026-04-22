# Apache Kafka manifest overlays

This folder holds small Kubernetes-native assets that sit beside the Helm release.

## Current contents

- `managed-csi-premium-storageclass.yaml`
- `namespace.yaml`

Apply the Premium SSD storage class manifest before the Helm release so the checked-in values can bind their PVCs consistently across AKS clusters.

Kafka credentials are created from the CLI instead of being checked into the repo. Use the command flow in `docs/az-cli-deployment.md` to create the `kafka-auth` secret with generated passwords.
