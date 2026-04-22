# OpenSearch architecture notes

OpenSearch should be treated as a stateful platform workload, not as a generic stateless deployment.

## Why this workload needs a different AKS design

OpenSearch combines JVM memory pressure, shard placement, persistent disk needs, and cluster coordination behavior. That means the cluster design should optimize for:

- predictable storage performance
- enough disk headroom for merges and recovery
- isolated node pools for platform-critical components
- deliberate API exposure and operator access
- clean backup and restore posture

## Recommended reference architecture

```text
+-------------------------------------------------------------------+
| AKS cluster                                                       |
|                                                                   |
|  system/app node pool                                             |
|   - cluster add-ons                                               |
|   - OpenSearch Dashboards (optional placement)                    |
|                                                                   |
|  osmgr node pool                                                  |
|   - Helm release: opensearch-manager                              |
|   - 3 replicas                                                    |
|   - roles: master                                                 |
|   - Premium SSD-backed PVCs                                       |
|                                                                   |
|  osdata node pool                                                 |
|   - Helm release: opensearch-data                                 |
|   - 3 replicas                                                    |
|   - roles: data, ingest, remote_cluster_client                   |
|   - Premium SSD-backed PVCs                                       |
|                                                                   |
|  OpenSearch API                                                   |
|   - ClusterIP only                                                |
|   - accessed through port-forward, jump host, or internal path    |
|                                                                   |
|  OpenSearch Dashboards                                            |
|   - Helm release: opensearch-dashboards                           |
|   - 2 replicas                                                    |
|   - internal Azure LoadBalancer                                   |
+-------------------------------------------------------------------+
```

## Design decisions

| Area | Recommendation | Notes |
| --- | --- | --- |
| Cluster baseline | Use AKS AVM wrappers | Aligns OpenSearch with the rest of the repo |
| Cluster-manager tier | Separate from data nodes | Protects elections and metadata operations |
| Data tier | StatefulSet with Premium SSD PVCs | Better fit for shard durability and latency |
| API exposure | Keep private | Use `kubectl port-forward`, bastion, or internal routing |
| Dashboards exposure | Internal load balancer | Easier operator access without public API exposure |
| Snapshots | Azure Blob Storage | PVCs are not backups |
| Authentication | Replace demo defaults quickly | Use secret-backed initial password and move to stronger cert and secret handling as the blueprint matures |

## AKS-specific guidance

### 1. Dedicated node pools

Start with three logical pool types:

- **system/app** for AKS add-ons and optional Dashboards placement
- **osmgr** for cluster-manager nodes
- **osdata** for data and ingest nodes

You can collapse these for short-lived labs, but the blueprint assumes dedicated pools so operational guidance stays production-minded from the start.
The checked-in AKS wrappers provision `systempool`, `osmgr`, and `osdata`. Because the default Helm values run three manager replicas and three data replicas with hard pod anti-affinity, the dedicated `osmgr` and `osdata` pools need at least three schedulable nodes each, or equivalent autoscaler headroom during install.

### 2. Storage choices

Use Azure Disk CSI for primary data paths and treat `managed-csi-premium` as the default starting point. This blueprint uses smaller PVCs for manager nodes and larger PVCs for data nodes because their operational roles are different.

### 3. Service exposure

- OpenSearch itself stays on `ClusterIP`
- Dashboards uses an internal load balancer
- administrative API access uses port-forward or an internal-only path

### 4. Role naming note

The OpenSearch project is steadily moving toward **cluster-manager** terminology, but the current Helm chart still uses keys such as `masterService` and examples with the `master` role. The blueprint keeps the chart-compatible values while using cluster-manager language in the surrounding guidance.

## Capacity planning starter values

| Tier | Replicas | PVC size | JVM heap | Suggested use |
| --- | --- | --- | --- | --- |
| Manager | 3 | 16 GiB | 1 GiB | Evaluation and smaller production-like labs |
| Data | 3 | 128 GiB | 4 GiB | Moderate indexing and search workloads |
| Dashboards | 2 | none | n/a | Operator-facing UI tier |

These are starting points, not target-state sizing guidance. Increase disk, memory, and node pool size based on shard count, retention, query latency, and indexing profile.
