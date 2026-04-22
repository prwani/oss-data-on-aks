# ClickHouse operations notes

Operational maturity for ClickHouse should cover more than pod health.

## Daily and weekly signals

| Area | What to watch |
| --- | --- |
| Keeper quorum | healthy Keeper pod count, leader election stability, and restart loops |
| Replica health | lagging replicas, fetch backlog, and read-only replica states |
| Storage | PVC usage, disk throughput, and node-level saturation during merges |
| Merge and mutation activity | `system.merges`, `system.mutations`, and long-running background tasks |
| Access and secrets | private service exposure, admin secret rotation, and audit expectations |

## Useful operational commands

```bash
export CLICKHOUSE_PASSWORD=$(kubectl get secret clickhouse-auth -n clickhouse -o jsonpath='{.data.admin-password}' | base64 --decode)

kubectl get pods,pvc -n clickhouse -o wide
kubectl logs statefulset/clickhouse-keeper -n clickhouse --tail=200

kubectl exec clickhouse-shard0-0 -n clickhouse -- clickhouse-client --user default --password "$CLICKHOUSE_PASSWORD" --query "SELECT database, table, bytes_on_disk FROM system.parts ORDER BY bytes_on_disk DESC LIMIT 10"

kubectl exec clickhouse-shard0-0 -n clickhouse -- clickhouse-client --user default --password "$CLICKHOUSE_PASSWORD" --query "SELECT database, table, is_leader, total_replicas, active_replicas FROM system.replicas FORMAT PrettyCompact"

kubectl exec clickhouse-shard0-0 -n clickhouse -- clickhouse-client --user default --password "$CLICKHOUSE_PASSWORD" --query "SELECT database, table, elapsed, progress FROM system.merges FORMAT PrettyCompact"
```

## Scaling guidance

Prefer these steps over ad hoc resizing:

1. grow PVC size or node class when merges and query latency show storage pressure first
2. add replicas when availability and read distribution are the problem
3. add shards when data volume or write throughput needs horizontal scale-out
4. keep Keeper quorum stable during scaling events; do not treat it like a disposable sidecar tier

## Backup and restore posture

- do not treat PVCs as backups
- validate backup tooling and restore procedures separately from the baseline install
- when integrating Azure Blob or another object store, use managed identity auth instead of shared keys
- test restore into a non-production cluster before calling the design production-ready

## Upgrade guidance

- pin the chart and ClickHouse versions you validated
- verify Keeper quorum before and after upgrades
- keep `kubectl get pvc` and replica-health queries in the upgrade checklist
- rerun shard and replica validation queries after each chart change

## Security and platform guidance

- keep the checked-in service shape private by default
- rotate the password stored in `clickhouse-auth` on a regular cadence
- create narrower-scoped database users for applications rather than reusing the bootstrap admin login
- keep future Azure storage integrations on managed identity-based auth

## Recommended runbooks

- replace a failed replica with its PVC intact
- recover Keeper quorum after a node disruption
- investigate merge backlog or disk pressure
- rotate the ClickHouse admin secret used by the chart
- validate cluster state after an AKS node image upgrade
