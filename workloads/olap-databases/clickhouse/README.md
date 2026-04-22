# ClickHouse on AKS

This blueprint is the starter path for running **ClickHouse** on AKS with AKS AVM as the cluster baseline.

## What this blueprint is optimizing for

- **AKS AVM baseline** for repeatable cluster creation
- **Terraform and Bicep** wrappers side by side
- **Bitnami ClickHouse chart `9.4.7`** pinned to **ClickHouse `25.7.5`**
- **One dedicated `clickhouse` user pool with 3 nodes** for ClickHouse and Keeper placement
- **Internal-only service exposure by default** using `ClusterIP` plus port-forward or an internal load balancer override
- **Per-replica Premium SSD PVCs** for ClickHouse and ClickHouse Keeper
- **Runtime secret creation** through `existingSecret` references instead of committing fake passwords

## Why this is not a typical AKS microservice

ClickHouse is a stateful analytical database platform, not a generic stateless web tier:

- data nodes are created as **StatefulSets** and keep their own PVC-backed disks
- **shards and replicas** determine scale-out and high availability, not just a deployment replica count
- **ClickHouse Keeper** maintains replication metadata and coordination quorum for replicated tables
- **background merges** continuously compact MergeTree parts, so disk headroom and I/O shape matter to query performance
- `kubectl get pvc` is a first-class validation step because each replica depends on a bound volume before it can serve data safely

Those characteristics are why this blueprint emphasizes dedicated node pools, internal-only access, existing secret references, and per-replica Azure Disk-backed storage from the start.

## Recommended starting pattern

| Layer | Recommendation | Why |
| --- | --- | --- |
| AKS baseline | Shared AVM wrapper | Keeps cluster creation consistent across workloads |
| Dedicated compute pool | `clickhouse` user pool with 3 nodes | Isolates OLAP storage and merge traffic from AKS system components |
| ClickHouse cluster | 2 shards × 2 replicas | Gives a concrete starter topology for sharding and replication |
| Keeper | 3 replicas | Keeps quorum and replication metadata highly available |
| Service exposure | `ClusterIP` only | Limits the database surface area |
| Persistent storage | `managed-csi-premium` | Sensible default for per-replica Premium SSD disks |
| Authentication | `auth.existingSecret` | Avoids committing fake admin passwords |

## Architecture visuals

![ClickHouse on AKS architecture](../../../blogs/clickhouse/assets/clickhouse-on-aks-architecture.svg)

*Custom AKS mapping for this repository. It shows ClickHouse shards and replicas, Keeper quorum, dedicated `clickhouse` node-pool placement, and per-replica PVC-backed storage.*

## Blueprint contents

- `docs/architecture.md`
- `docs/portal-deployment.md`
- `docs/az-cli-deployment.md`
- `docs/operations.md`
- `infra/terraform`
- `infra/bicep`
- `kubernetes/helm`
- `kubernetes/manifests`
- `scripts/az-cli`

## Standard release name

The workload guidance assumes the Helm release name `clickhouse`. With that release name, the chart creates:

1. ClickHouse services rooted at `clickhouse`
2. shard StatefulSets such as `clickhouse-shard0` and `clickhouse-shard1`
3. Keeper StatefulSet `clickhouse-keeper`

Using the documented release name keeps the validation commands and operational runbooks aligned.

## Scope of the current implementation

This blueprint now includes:

- AKS wrappers with a concrete `clickhouse` node pool definition
- a pinned Bitnami chart deployment with shard, replica, and Keeper sizing
- runtime secret creation guidance that uses `existingSecret`
- Premium SSD storage class and namespace manifests
- internal-only access guidance for the ClickHouse service
- a publish-ready blog package in [`blogs/clickhouse`](../../../blogs/clickhouse)

The checked-in content intentionally stops short of provisioning backup storage. When you add Blob-backed backup tooling or object-storage-integrated engines, use workload identity and managed identity-based storage access rather than shared keys.
