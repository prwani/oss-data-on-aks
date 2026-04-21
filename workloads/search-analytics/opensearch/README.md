# OpenSearch on AKS

This blueprint is the first expanded workload in the repository and the reference pattern for stateful search and analytics platforms on AKS.

## What this blueprint is optimizing for

- **AKS AVM baseline** for the cluster foundation
- **Terraform and Bicep** entry points side by side
- **Portal-first** and **`az` CLI-first** operator journeys
- **Stateful workload guidance** for storage, node pools, private access, and operations
- **TechCommunity-ready blog content** aligned to the implementation assets in [`blogs/opensearch`](../../../blogs/opensearch)

## Recommended starting pattern

| Layer | Recommendation | Why |
| --- | --- | --- |
| AKS baseline | Shared AVM wrapper | Keeps cluster creation consistent across workloads |
| Cluster-manager tier | Dedicated Helm release and dedicated node pool | Protects elections and cluster metadata |
| Data tier | Dedicated Helm release and dedicated node pool | Isolates shard-heavy storage and indexing traffic |
| OpenSearch API | `ClusterIP` only | Limits attack surface |
| Dashboards | Internal Azure load balancer | Gives operators access without exposing the API publicly |
| Persistent storage | `managed-csi-premium` | Sensible default for durable SSD-backed volumes |
| Snapshots | Azure Blob Storage | External recovery point beyond PVCs |

## Blueprint contents

- `docs/architecture.md`
- `docs/portal-deployment.md`
- `docs/az-cli-deployment.md`
- `docs/operations.md`
- `infra/terraform/main.tf`
- `infra/terraform/terraform.tfvars.example`
- `infra/bicep/main.bicep`
- `infra/bicep/main.bicepparam`
- `kubernetes/helm`
- `kubernetes/manifests`

## Standard release names

The workload guidance assumes the following Helm release names:

1. `opensearch-manager`
2. `opensearch-data`
3. `opensearch-dashboards`

Using stable release names keeps service discovery, example manifests, and documentation aligned.

## Scope of the current implementation

This blueprint now includes:

- a documented target architecture
- example Azure deployment wrappers for AKS baseline and snapshot storage
- Helm values for manager nodes, data nodes, and Dashboards
- namespace and secret examples
- a two-part blog package for external publication

It does **not** yet claim to automate every production hardening task end to end. Snapshot repository registration, certificate replacement, and private endpoint integration should still be validated for the target environment.
