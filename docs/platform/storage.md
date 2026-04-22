# Shared storage guidance

Many of the target platforms in this repository are durable data systems. Treat storage as part of the blueprint contract, not as an implementation detail that can be filled in later.

## Storage baseline across the repo

- use the AKS CSI drivers enabled by the shared platform baseline
- default durable stateful paths to **Azure Disk CSI** unless the workload clearly needs something else
- keep **ephemeral scratch**, **durable workload data**, and **Azure object-storage integrations** documented separately
- make PVC sizing, storage-class choice, and retention assumptions visible in the workload docs
- define backup, restore, and disaster-recovery expectations before the first install guide is considered complete

## Pick the right storage pattern

| Workload pattern | Recommended Azure-backed approach | Notes |
| --- | --- | --- |
| StatefulSet data, quorum logs, broker logs, database volumes | Azure Disk CSI (`managed-csi-premium` or environment-approved equivalent) | best default for durable per-pod storage |
| Shared content or charts that truly need `ReadWriteMany` | Azure Files CSI only if the workload requires shared access | document performance tradeoffs before defaulting to RWX |
| Spill, cache, shuffle, temp, or scratch space | `emptyDir` or other explicitly ephemeral storage | keep it separate from the durable data path |
| Blob, ADLS, snapshot export, or archive integration | Azure Storage through managed identity or workload identity | do not fall back to shared keys in checked-in config |

## Repo conventions for workload authors

Each workload should make these decisions explicit:

1. **What persists?** Identify controller metadata, broker logs, warehouse files, databases, or other durable state.

2. **What is temporary?** Call out spill paths, cache directories, or scratch work that can be rebuilt.

3. **Which storage class is expected?** If the workload needs `managed-csi-premium` or another class, keep that visible in `kubernetes/manifests` and the deployment guide.

4. **How much capacity is the starter using?** Document replica count, PVC size, and any retention math that operators must understand.

5. **What is the backup and restore posture?** Distinguish PVC durability from true workload recovery.

## Storage-class guidance

The expanded workloads usually follow one of these patterns:

- reuse the cluster's existing Premium CSI class when it already matches the required behavior
- create a small checked-in storage-class manifest when the workload needs a predictable name
- document any premium SKU, snapshot, or expansion requirement in `docs/architecture.md` and `docs/operations.md`

If a workload needs a storage-class manifest, keep it next to the workload in `kubernetes/manifests` instead of hiding it in an external wiki.

## Backup and disaster recovery

PVC retention is not the same as disaster recovery. Workload docs should say which of these apply:

- retained PVCs are enough for same-cluster node replacement
- application-native backup or snapshot workflows are required
- cross-cluster replication or restore drills are needed
- Azure object storage is part of the backup path and therefore needs workload identity/RBAC

## Validation steps worth documenting

Keep these kinds of checks in the workload deployment or operations docs:

```bash
kubectl get storageclass
kubectl get pvc -n <namespace>
kubectl describe pvc <claim-name> -n <namespace>
kubectl get pv
```

For stateful workloads, also document the capacity signals that matter, such as:

- sustained disk usage thresholds
- replica recovery time
- snapshot success or failure
- throughput or latency symptoms that mean the chosen disk SKU is no longer adequate
