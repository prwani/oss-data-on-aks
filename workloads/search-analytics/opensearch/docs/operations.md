# OpenSearch operations notes

Operational maturity for OpenSearch should cover more than pod health.

## Daily and weekly signals

| Area | What to watch |
| --- | --- |
| Cluster health | cluster status, unassigned shards, node count |
| Storage | disk usage, watermarks, PVC pressure, Azure Disk saturation |
| JVM | heap usage, GC pressure, CPU throttling |
| Query path | search latency, indexing latency, rejected thread pools |
| Access | Dashboards reachability and API exposure drift |

## Snapshots and restore

- do not treat persistent volumes as backups
- register a snapshot repository backed by Azure Blob Storage
- keep the checked-in path on AKS workload identity so OpenSearch never needs a storage account key or SAS token
- validate restore into a non-production cluster before you call the design production-ready
- keep snapshot storage permissions separate from routine user credentials

The checked-in manager and data Helm values install `repository-azure`, load `azure.client.default.account` from the `opensearch-snapshot-settings` secret into the OpenSearch keystore, and keep `azure.client.default.token_credential_type: managed_identity` in `opensearch.yml`. When you deploy the starter snapshot storage path, the Azure wrappers also create a user-assigned managed identity, federated credentials for the manager and data service accounts, and a least-privilege `Storage Blob Data Contributor` assignment on the snapshot container.

Example repository registration:

```http
PUT /_snapshot/azure-managed-identity
{
  "type": "azure",
  "settings": {
    "client": "default",
    "container": "opensearch-snapshots"
  }
}
```

## Scaling guidance

Prefer these steps over ad hoc cluster resizing:

1. increase data node capacity when disk pressure or shard density is the main problem
2. revisit heap and pod memory when JVM pressure is the main problem
3. scale Dashboards independently from data plane components
4. keep cluster-manager capacity steady unless cluster coordination is the bottleneck

## Upgrade guidance

- pin tested chart and OpenSearch versions
- review plugin compatibility before upgrades
- keep manager and data releases on a controlled upgrade sequence
- snapshot before major version changes
- validate Dashboards compatibility with the target OpenSearch version

## Security follow-up items

- replace default or demo certificate paths before production rollout
- rotate the initial admin password after bootstrap
- keep Azure integrations on workload identity and avoid reintroducing storage account keys
- review internal load balancer and NSG paths regularly

## Recommended runbooks

- restore from snapshot
- replace a failed data node
- recover from disk watermark pressure
- rotate credentials used by Dashboards
- validate cluster state after an AKS node image upgrade
