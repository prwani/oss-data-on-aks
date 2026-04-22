# ClickHouse architecture notes

ClickHouse should be modeled as a stateful analytical database platform with deliberate storage and topology choices.

## Why this workload needs a different AKS design

ClickHouse combines local MergeTree storage, replica coordination, background merges, and query patterns that can stress both memory and I/O. The AKS design therefore needs to optimize for:

- durable and predictable disk performance
- enough node and disk headroom for merges, fetches, and recovery
- explicit shard and replica layout
- reliable Keeper quorum
- private client access and controlled credential handling

## Recommended reference architecture

```text
+-------------------------------------------------------------------+
| AKS cluster                                                       |
|                                                                   |
|  systempool                                                       |
|   - AKS add-ons                                                   |
|                                                                   |
|  clickhouse user pool (3 nodes)                                   |
|   - StatefulSet: clickhouse-shard0 (2 replicas)                   |
|   - StatefulSet: clickhouse-shard1 (2 replicas)                   |
|   - StatefulSet: clickhouse-keeper (3 replicas)                   |
|   - Service: clickhouse (ClusterIP, ports 8123 and 9000)          |
|   - Premium SSD-backed PVC per ClickHouse replica                 |
|   - Premium SSD-backed PVC per Keeper replica                     |
|                                                                   |
|  Operator access                                                  |
| - kubectl port-forward svc/clickhouse 8123:8123 9000:9000 |
|   - optional internal Azure LoadBalancer override                 |
+-------------------------------------------------------------------+
```

## Design decisions

| Area | Recommendation | Notes |
| --- | --- | --- |
| Cluster baseline | Use AKS AVM wrappers | Aligns ClickHouse with the rest of the repo |
| Dedicated node pool | `clickhouse` user pool with taint `dedicated=clickhouse:NoSchedule` | Keeps OLAP storage and merge activity off the system pool |
| Topology | 2 shards × 2 replicas | Gives a concrete starter for both scale-out and replication |
| Keeper | 3 replicas | Protects coordination quorum for replicated tables |
| Storage | Premium SSD PVCs via `managed-csi-premium` | Better default for MergeTree data and Keeper metadata |
| Service exposure | Keep private | Use port-forward or an internal-only path |
| Secrets | `auth.existingSecret` | Avoids committing passwords to source control |

## AKS-specific guidance

### 1. Dedicated node pool and sizing

The checked-in wrappers provision `systempool` plus one dedicated `clickhouse` pool with three nodes. That pool carries the `dedicated=clickhouse:NoSchedule` taint, and both ClickHouse and Keeper values tolerate it.

This workload can schedule multiple stateful pods per node, so the node size matters more than the raw node count alone. The example wrappers use `Standard_E8ds_v5` for the dedicated pool to leave space for MergeTree reads, background merges, and Keeper processes.

### 2. Shards, replicas, and Keeper

The pinned Helm values deploy:

- `shards: 2`
- `replicaCount: 2`
- `keeper.replicaCount: 3`

This gives you a concrete topology to validate distributed tables, replica health, and Keeper quorum instead of a single-node demo footprint.

### 3. Per-replica PVCs

Each ClickHouse pod gets its own Azure Disk-backed PVC, and each Keeper pod gets its own smaller PVC for metadata durability. That is one of the clearest differences from a stateless microservice rollout.

Validate `kubectl get pvc -n clickhouse` as part of every install or upgrade, not only `kubectl get pods`.

### 4. Background merges and disk headroom

ClickHouse writes data in parts and merges those parts in the background. Merge operations are local to each replica, so the disk attached to each replica is part of the query-performance story.

This means AKS operators should monitor:

- PVC usage growth
- merge backlog and mutations
- node disk saturation and noisy-neighbor effects
- replica recovery time after a pod move or restart

## Capacity planning starter values

| Component | Replicas | PVC size | Container memory | Purpose |
| --- | --- | --- | --- | --- |
| ClickHouse | 4 pods total across 2 shards | 128 GiB per replica | 8 GiB limit | analytical query and ingest path |
| Keeper | 3 | 16 GiB per replica | 1 GiB limit | metadata coordination and quorum |
| Service | 1 ClusterIP | none | n/a | private client entry point |

These are starter values for a reusable blueprint, not a production sizing claim. Increase PVC size, node memory, or shard count based on dataset size, background merge load, and query concurrency.
