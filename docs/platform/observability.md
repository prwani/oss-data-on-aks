# Shared observability guidance

Each workload blueprint should plug into a common operational model so operators can move between blueprints without relearning how health, validation, and runbooks are documented.

## Minimum expectations

- **cluster health visibility** for AKS control plane, nodes, and add-ons
- **node-pool and scheduling visibility** so dedicated workload pools and taints can be validated
- **workload-specific logs and metrics** that go beyond `kubectl get pods`
- **alerting for storage pressure, restarts, and replica health**
- **backup, restore, or replication signals** for stateful platforms

## Shared observability layers

| Layer | What to capture | Where the repo should document it |
| --- | --- | --- |
| AKS platform | node readiness, pool scaling, CSI health, cluster events, Azure Monitor integration | shared platform docs plus workload deployment validation |
| Kubernetes workload | pod readiness, PVC binding, rollout status, namespace events | workload deployment and operations docs |
| Application/runtime | broker health, query success, coordinator status, dashboards, operators, jobs | workload `docs/operations.md` |
| Recovery posture | backup jobs, snapshot status, restore drills, replication lag | workload `docs/operations.md` |

## What a good workload operations doc should contain

The expanded workloads now use `docs/operations.md` as the day-2 companion to the install guide. At minimum, keep these sections specific and runnable:

- daily and weekly signals
- useful validation or troubleshooting commands
- scaling guidance
- upgrade guidance
- backup and restore or DR posture when the workload is stateful
- security or platform follow-up items
- recommended runbooks

If operators would need the command during rollout, upgrade, or incident response, keep it in the workload folder.

## Validation commands worth standardizing

These commands appear in many workload guides because they validate AKS placement, rollout, and services before you move to workload-native tooling:

```bash
kubectl get nodes
kubectl get pods -n <namespace> -o wide
kubectl get svc -n <namespace>
kubectl get pvc -n <namespace>
kubectl describe <resource> <name> -n <namespace>
helm list -n <namespace>
```

Add workload-native checks after the Kubernetes basics, such as SQL queries, broker metadata, chart hook status, or API health probes.

## Alert and dashboard themes

For most blueprints in this repo, operators should have visibility into:

- restart loops and failed chart hooks
- unschedulable pods caused by pool taints, missing capacity, or PVC binding issues
- disk pressure and storage growth
- replica health, controller leadership, or worker availability
- private endpoint or internal load balancer reachability

## Suggested rollout pattern

1. start with platform telemetry for AKS
2. add workload-native metrics, dashboards, and validation commands
3. capture runbooks inside the workload folder so the blueprint stays self-contained
