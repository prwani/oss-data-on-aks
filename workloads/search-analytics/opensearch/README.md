# OpenSearch on AKS

This blueprint is the starter path for running **OpenSearch** on AKS with a shared AKS AVM cluster baseline.

## Intended scope

- AKS baseline from shared Terraform and Bicep assets
- OpenSearch-specific installation path
- portal-first and `az` CLI-first operator guidance
- storage, networking, and operational guidance for a stateful search platform
- blog alignment with [`blogs/opensearch`](../../../../blogs/opensearch)

## Current scaffold

- `docs/architecture.md`
- `docs/portal-deployment.md`
- `docs/az-cli-deployment.md`
- `docs/operations.md`
- `infra/terraform/main.tf`
- `infra/bicep/main.bicep`
- `kubernetes/helm`
- `kubernetes/manifests`

