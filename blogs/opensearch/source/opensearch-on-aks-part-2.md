# OpenSearch on AKS, part 2: production-minded design for stateful search clusters

**Publication target:** Microsoft TechCommunity > Azure > Linux and Open Source Blog

## Summary

In Part 1, I focused on getting OpenSearch onto AKS with a reusable Azure-first blueprint. In this follow-up, I want to focus on what changes when you stop treating OpenSearch like a quick lab and start treating it like a durable platform workload.

That means thinking seriously about cluster-manager versus data roles, Azure Disk choices, disk headroom, internal access, snapshot posture, and the operational signals that matter after the initial deployment day.

## OpenSearch is not just another deployment

It is tempting to treat every Kubernetes workload the same way:

- pick a chart
- create a few replicas
- expose a service
- scale when needed

That works for a lot of stateless application services. It is not enough for OpenSearch.

OpenSearch cares about:

- where shard data lives
- how quickly a node can recover
- how much heap versus filesystem cache is available
- how much free disk is left during merges and relocation
- whether elections and metadata updates remain stable during maintenance

On AKS, those concerns translate into concrete platform decisions.

## Checked-in baseline from Part 1

This follow-up assumes the same checked-in deployment contract as Part 1.

| Component | Checked-in version | Evidence in repo |
| --- | --- | --- |
| Manager and data charts | `opensearch/opensearch` `3.6.0` | `workloads/search-analytics/opensearch/kubernetes/helm/README.md` |
| Dashboards chart | `opensearch/opensearch-dashboards` `3.6.0` | `workloads/search-analytics/opensearch/kubernetes/helm/README.md` |

The checked-in values intentionally inherit runtime images from those chart defaults, so `3.6.0` is the repo-backed version to revalidate before publication.


## Architecture recap: why storage and PVCs matter

Before talking about node pools and operational posture, it helps to make the AKS mapping explicit.

![Combined OpenSearch-on-AKS architecture](../assets/opensearch-on-aks-combined-architecture.svg)

*Custom AKS mapping for this repository. It combines OpenSearch cluster roles, shard/replica behavior, dedicated AKS node pools, StatefulSets, and per-pod PVC-backed Azure Disks.*

This is also the key difference from a normal stateless microservice:

- manager pods each need their **own PVC-backed disk** for cluster metadata durability
- data pods each need their **own PVC-backed disk** for primary and replica shard storage
- a pod can stay `Pending` simply because its **PersistentVolumeClaim** is not yet `Bound`

That is why storage classes, per-pod Azure Disks, and PVC validation show up so prominently in the AKS guidance for OpenSearch.

## 1. Split manager and data roles early

Even if you begin with a small cluster, it helps to separate cluster-manager and data responsibilities in the blueprint.

That is why this repo now uses:

- `opensearch-manager` for manager nodes
- `opensearch-data` for data and ingest nodes
- `opensearch-dashboards` for the UI tier

The current Helm chart still uses `masterService` and `master` naming in its values, but the operating intent is the modern cluster-manager/data split.

Why this matters:

- manager nodes protect elections and cluster metadata
- data nodes absorb indexing and query pressure
- scaling the data plane should not destabilize cluster coordination
- troubleshooting becomes easier because responsibilities are clearer

## 2. Use dedicated AKS node pools where possible

One of the easiest mistakes in early AKS deployments is mixing everything onto a single general-purpose pool.

A better pattern is:

| Node pool | Suggested use |
| --- | --- |
| system/app | AKS add-ons and optional Dashboards placement |
| osmgr | manager nodes |
| osdata | data and ingest nodes |

This design keeps noisy, disk-heavy search workloads away from unrelated application pods and gives you independent scaling decisions for the core OpenSearch tiers.

## 3. Treat storage as a first-class design concern

For OpenSearch on AKS, the disk choice is not a side detail.

The current blueprint uses **Azure Disk CSI Premium SSD** as the default starting point because it is a more natural fit for durable per-pod state than shared file-based storage.

The repo currently starts with:

- smaller PVCs for manager nodes
- larger PVCs for data nodes
- Azure Blob Storage as the target for snapshots

That does not mean the default sizes are universally correct. It means the blueprint makes storage visible and editable from day one.

## 4. Keep the API private and expose Dashboards carefully

Many quick demos make the OpenSearch API public because it feels convenient. That convenience usually turns into a security problem later.

The repo’s starting recommendation is:

- OpenSearch API on `ClusterIP`
- Dashboards on an **internal** Azure load balancer
- admin and debugging access through port-forward or an internal-only path

That pattern keeps the operational workflow workable without publishing the core search API.

## 5. Keep disk headroom, not just total capacity

One of the most common operational surprises with stateful search platforms is that running out of *headroom* hurts before running out of total disk.

OpenSearch needs spare capacity for:

- segment merges
- shard relocation
- recovery
- temporary imbalance during maintenance

A useful mental model is:

```text
required disk ~= raw data * (1 + replicas) * operational overhead + free-space headroom
```

The exact factor depends on your workload, but the important point is simple: do not size for only the raw data volume.

## 6. Snapshots are mandatory, not optional

Persistent volumes improve resilience, but they are not a backup strategy.

That is why the OpenSearch wrappers in the repo also include starter Azure resources for snapshot storage. The current implementation does not pretend to automate every detail of snapshot repository registration yet, but it makes the external recovery target part of the blueprint rather than an afterthought.
The checked-in path is also intentionally keyless: the starter storage account has shared-key access disabled, AKS workload identity is enabled, and the snapshot service accounts are bound to a user-assigned managed identity through federated credentials.

Before calling a deployment production-ready, validate:

- snapshot creation
- restore into a separate cluster
- retention and storage lifecycle
- managed-identity credential handling for the snapshot path

## 7. Monitor the signals that matter

A healthy AKS cluster does not automatically mean a healthy OpenSearch cluster.

At minimum, watch:

- cluster status and unassigned shards
- disk usage and watermarks
- node count and restart behavior
- JVM pressure and GC symptoms
- indexing and search latency
- snapshot success or failure
- Dashboards reachability and API exposure drift

This is also where having separate manager and data releases helps. When something goes wrong, you can reason about the control plane and data plane independently.

## 8. Plan upgrades and maintenance deliberately

Stateful platforms need calmer upgrade habits than stateless microservices.

Recommended practices:

1. pin tested chart and OpenSearch versions
2. snapshot before major changes
3. validate plugin and Dashboards compatibility
4. review AKS node image changes like you would any other platform dependency
5. keep a runbook for failed node replacement and post-maintenance validation

## How this shapes the repo

The value of this second post is not just the advice. It is that the advice now maps directly to repo assets:

- architecture guidance in `workloads/search-analytics/opensearch/docs/architecture.md`
- operations guidance in `workloads/search-analytics/opensearch/docs/operations.md`
- manager, data, and Dashboards Helm values under `kubernetes/helm`
- Azure deployment wrappers under `infra`

That is the pattern I want this repository to follow for the rest of the workload backlog as well.

## Closing thought

Running OpenSearch on AKS is very achievable. The difference between a short-lived demo and a credible platform blueprint is mostly in the design decisions you make around storage, access, topology, and recovery.

If Part 1 answers, “How do I get OpenSearch onto AKS with a clean Azure baseline?”, then Part 2 answers, “What does a better long-term operating posture look like once it is there?”
