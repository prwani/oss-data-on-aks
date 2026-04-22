# `<workload>` operations notes

Turn this file into the day-2 companion for the blueprint. Keep it specific to the checked-in values, manifests, and release names.

## Daily and weekly signals

| Area | What to watch |
| --- | --- |
| Rollout health | pods, jobs, or StatefulSets settle without repeated restarts |
| Scheduling | dedicated pool placement and taints behave as expected |
| Storage | PVC binding, disk growth, and any scratch-volume pressure stay healthy |
| Service path | internal service or private endpoint still works |
| Workload-native health | replace with the metrics, APIs, or CLI checks that actually matter |

## Useful operational commands

Start with repo-standard Kubernetes checks:

```bash
kubectl get pods -n <namespace> -o wide
kubectl get svc -n <namespace>
kubectl get pvc -n <namespace>
helm list -n <namespace>
```

Add the workload-native commands operators will really use, such as SQL checks, broker metadata, admin CLI commands, or operator status queries.

## Scaling guidance

Document the first levers operators should consider:

- node count or VM size
- replica count
- memory or JVM tuning
- PVC size or storage SKU
- any coordinator, scheduler, or control-plane constraints

## Backup and restore posture

Explain whether retained PVCs are enough for same-cluster recovery, whether workload-native backup workflows are required, and which Azure permissions or storage integrations are involved.

## Upgrade guidance

Describe the health gates to confirm before and after upgrades, for example:

1. PVCs and pods are healthy
2. no failed hook jobs or pending migrations exist
3. dedicated pool capacity is available for rolling updates
4. workload-native smoke tests still pass after the rollout

## Security and platform guidance

Capture the day-2 items operators should keep in mind:

- secret rotation
- admin-account handling
- certificate renewal
- workload identity or Azure RBAC follow-up
- any Pod Security or privileged-container caveats

## Recommended runbooks

List the procedures worth documenting before the blueprint is called complete, for example:

- recover from a failed rollout
- replace a node or pod while preserving state
- rerun migrations or bootstrap jobs safely
- validate private access after a network change
- scale up before storage pressure becomes urgent
