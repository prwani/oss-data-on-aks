# Trino operations notes

Operational maturity for Trino should cover more than pod health.

## Daily and weekly signals

| Area | What to watch |
| --- | --- |
| Coordinator health | CPU saturation, planning latency, restarts, and query queue depth |
| Worker fleet | worker count, pod churn, spill directory pressure, and long-running tasks |
| Query memory | rejected or killed queries, memory limit breaches, and spill frequency |
| Catalog surface | unexpected catalog drift, connector errors, or broken metadata endpoints |
| Access path | private service exposure, internal load balancer drift, and audit expectations |

## Useful operational commands

```bash
kubectl get pods -n trino -o wide
kubectl logs deploy/trino-coordinator -n trino --tail=200

kubectl exec deploy/trino-coordinator -n trino -- trino --execute "SELECT query_id, state, queued_time_ms, analysis_time_ms FROM system.runtime.queries ORDER BY created DESC LIMIT 20"

kubectl exec deploy/trino-coordinator -n trino -- trino --execute "SELECT node_id, coordinator, http_uri, node_version FROM system.runtime.nodes"
```

## Scaling guidance

Prefer these steps over ad hoc resizing:

1. add worker replicas or larger worker nodes when concurrency and scan volume are the main bottlenecks
2. revisit heap, `query.max-memory-per-node`, and `memory.heap-headroom-per-node` together rather than changing one memory knob in isolation
3. keep the coordinator reserved for planning and scheduling work instead of enabling `includeCoordinator`
4. monitor spill usage before raising memory limits blindly; spill is slower, but it is safer than coordinator or worker OOM loops

## Upgrade guidance

- pin the chart and Trino versions you validated
- keep worker graceful shutdown enabled so AKS maintenance events are less disruptive to active queries
- test chart upgrades on a non-production cluster with the same catalog mix
- rerun the `tpch` validation queries and any environment-specific queries after upgrades

## Security and platform guidance

- keep the checked-in service shape private by default
- add Trino authentication before opening the service to more than a tightly controlled operator path
- use Kubernetes secrets or workload identity-backed configuration for real connector credentials
- for Azure Storage-backed catalogs, use managed identity auth and do not fall back to storage account keys

## Recommended runbooks

- worker spill pressure or node ephemeral storage pressure
- coordinator restart or query queue buildup
- onboarding a new catalog with workload identity
- validation after an AKS node image upgrade
- rollback of a Trino chart upgrade
