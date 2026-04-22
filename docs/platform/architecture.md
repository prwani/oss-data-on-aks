# Shared platform architecture

The repository is organized around one shared AKS platform baseline plus workload-specific overlays. This document explains the platform contract that every workload blueprint is expected to inherit before it adds chart values, manifests, or day-2 notes.

## What the shared platform layer owns

- **AKS cluster creation** through the shared AVM wrappers in [`platform/aks-avm`](../../platform/aks-avm)
- **Terraform and Bicep parity** so each workload can offer both IaC entry points without redefining the cluster baseline
- **Cross-cutting platform choices** such as system pool shape, identity defaults, CSI drivers, and repo-wide naming expectations
- **Shared navigation docs** that explain the portal-first and `az` CLI-first operator journeys once instead of repeating them in every workload

## Baseline shape used across the repo

| Layer | Shared expectation | What workload folders add |
| --- | --- | --- |
| Resource group and naming | keep cluster, resource-group, and namespace names predictable across portal, Terraform, and Bicep flows | workload-specific prefixes and environment suffixes |
| AKS baseline | provision AKS from the AVM wrappers; keep the shared wrapper pinned to tested module versions | workload-specific pool sizing and any cluster options that must differ |
| System node pool | retain a small `systempool` for AKS add-ons and shared services | document why workload pods should stay off the system pool |
| Dedicated workload pool | add at least one user pool for the workload data plane or control plane | labels, taints, sizing, and replica placement rules |
| Kubernetes assets | keep namespace, storage-class, and small helper manifests beside the workload | chart values, extra manifests, and release-specific notes |
| Service exposure | stay internal-first by default | internal load balancer, private ingress, or broker/listener patterns when truly required |
| Operations model | keep monitoring, validation, and runbooks explicit | workload-native metrics, health checks, upgrade rules, and backup workflows |

## Patterns the expanded workloads now share

1. **Shared AKS baseline first:** workload folders call into `platform/aks-avm` instead of duplicating cluster creation logic.

2. **Dedicated node placement:** each workload describes one or more dedicated user pools, then lines up Helm values or manifests with `agentpool` labels and matching taints.

3. **Dual IaC wrappers:** Terraform and Bicep stay side by side and should describe the same starter cluster shape.

4. **Internal-only defaults:** most checked-in blueprints assume `ClusterIP`, port-forward, or private-only access until a workload-specific external design is documented.

5. **Secret-free source control:** the repo can include examples, but real passwords, keys, and certificates are created out of band and referenced by runtime secrets.

6. **Architecture plus operations docs:** every workload should explain why it is not “just another AKS app,” then follow that with concrete validation and day-2 guidance.

## What belongs in a workload folder

Use the template in [`templates/workload-template`](../../templates/workload-template) and keep the following baseline:

- `README.md` that explains the workload goal, starter topology, and scope
- `docs/architecture.md` for the AKS-specific design choices
- `docs/portal-deployment.md` and `docs/az-cli-deployment.md` for the two shared operator journeys
- `docs/operations.md` for day-2 validation, upgrades, and runbooks
- `infra/terraform` and `infra/bicep` wrappers that extend the shared platform baseline
- `kubernetes/helm` and `kubernetes/manifests` content for workload-local assets
- `scripts/az-cli` notes or helper scripts only when they wrap the documented flows without hiding important choices

## Decision checklist for new blueprints

| Area | Questions to settle early | Where to record the answer |
| --- | --- | --- |
| Topology | Is this a stateless service, a quorum-based control plane, or a stateful data platform? | `README.md`, `docs/architecture.md` |
| Node pools | Does the workload need a dedicated user pool, taints, or zone-aware spread? | Terraform and Bicep wrappers, Helm values/manifests |
| Networking | Can the service stay internal-only? If not, what private routing pattern is acceptable? | `docs/architecture.md`, deployment guides |
| Storage | What is durable, what is scratch, and what is backed up? | `docs/architecture.md`, `docs/operations.md`, manifests |
| Identity | Which Azure APIs or storage services need managed identity or workload identity? | `docs/platform/security.md` references plus workload docs |
| Observability | Which logs, metrics, and runbooks are required before calling the blueprint usable? | `docs/operations.md` |

## When to update shared docs

Update the shared docs in `docs/platform` or `docs/user-journeys` when a change affects more than one workload, such as:

- a new repo-wide baseline requirement for node pools or identity
- a repeated operator step that should be explained once centrally
- a shared storage, observability, or security convention that multiple workloads now depend on
