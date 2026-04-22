# Trino architecture notes

Trino should be treated as a distributed query service with clear separation between coordinator, workers, catalogs, and query spill behavior.

## Why this workload needs a different AKS design

Trino is not durable in the same way as ClickHouse or OpenSearch, but it still is not a simple web API deployment. The AKS design needs to account for:

- a single **coordinator** that handles parsing, planning, scheduling, and cluster state
- **workers** that absorb CPU, memory, and node-local spill pressure during joins and aggregations
- **catalogs** as configuration artifacts that define what data Trino can actually reach
- deliberate private access because a wide-open SQL endpoint is rarely the right default

## Recommended reference architecture

```text
+-------------------------------------------------------------------+
| AKS cluster                                                       |
|                                                                   |
|  systempool                                                       |
|   - AKS add-ons                                                   |
|                                                                   |
|  trino user pool (3 nodes)                                        |
|   - Deployment: trino-coordinator (1 replica)                     |
|   - Deployment: trino-worker (3 replicas)                         |
|   - Service: trino (ClusterIP, port 8080)                         |
|   - Headless service: trino-worker                                |
|   - Worker spill path: /var/trino/spill backed by emptyDir        |
|                                                                   |
|  Catalog configuration                                            |
|   - tpch catalog mounted by the Helm chart                        |
|                                                                   |
|  Operator access                                                  |
| - kubectl port-forward svc/trino 8080:8080 |
|   - optional internal Azure LoadBalancer override                 |
+-------------------------------------------------------------------+
```

## Design decisions

| Area | Recommendation | Notes |
| --- | --- | --- |
| Cluster baseline | Use AKS AVM wrappers | Aligns Trino with the rest of the repo |
| Dedicated node pool | `trino` pool with taint `dedicated=trino:NoSchedule` | Keeps query execution off the system pool |
| Coordinator placement | Same dedicated pool as workers | Simple starting pattern without a second user pool |
| Worker count | 3 replicas | Matches the default node count and gives parallelism for `tpch` |
| Spill path | Worker `emptyDir` volume | Required once queries exceed in-memory limits |
| Service exposure | Keep the coordinator service private | Use port-forward or an internal-only load balancer path |
| Catalog choice | `tpch` only in the checked-in values | Keeps the blueprint runnable without extra infrastructure |

## AKS-specific guidance

### 1. Dedicated node pool

The checked-in wrappers provision `systempool` plus one dedicated `trino` user pool with three nodes. That pool carries the `dedicated=trino:NoSchedule` taint, and the Helm values include matching tolerations.

This is important even though Trino is not a StatefulSet workload. Large distributed SQL queries can consume CPU, heap, and ephemeral disk aggressively enough that sharing tiny system nodes with the control plane is a poor default.

### 2. Coordinator and worker split

Trino always has one coordinator. The blueprint keeps `node-scheduler.include-coordinator=false` so user queries execute on workers instead of borrowing coordinator capacity.

This is one of the biggest differences from a stateless microservice: you do not just add replicas of a single homogeneous pod type. You size the coordinator for planning and control-plane work, and you size workers for query execution.

### 3. Query memory and spill

The pinned Helm values set:

- coordinator JVM heap: `4G`
- worker JVM heap: `8G`
- cluster query memory: `6GB`
- cluster query total memory: `9GB`
- worker spill path: `/var/trino/spill`

Worker spill is backed by `emptyDir`, which means AKS node-local storage becomes a first-class operating concern. Watch node ephemeral storage pressure during wide joins, large sorts, and window-heavy workloads.

### 4. Catalog onboarding

The checked-in values deliberately keep only the `tpch` catalog so the cluster is runnable without extra secrets, metadata services, or storage endpoints.

When you add real lakehouse or warehouse catalogs:

- keep catalog properties in source control
- mount secrets through Kubernetes objects rather than inline values
- use Azure workload identity and managed identity auth for Azure Storage-backed catalogs
- treat catalog rollout as part of the workload release, not a manual afterthought

## Capacity planning starter values

| Component | Replicas | JVM heap | Container memory | Purpose |
| --- | --- | --- | --- | --- |
| Coordinator | 1 | 4 GiB | 6 GiB | SQL parsing, planning, scheduling, UI |
| Worker | 3 | 8 GiB | 12 GiB | Query execution and local spill |
| Catalog | `tpch` | n/a | n/a | Built-in validation and smoke testing |

These are starter values for a reusable blueprint, not a final production sizing target. Increase worker memory, node size, or replica count based on concurrency, join size, and spill behavior in the target environment.
