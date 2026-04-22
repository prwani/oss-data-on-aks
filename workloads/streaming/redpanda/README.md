# Redpanda on AKS

This blueprint is the opinionated starter pattern for running Redpanda on AKS with a shared AKS AVM cluster baseline, a dedicated `rpbroker` pool, and the pinned `redpanda/redpanda` Helm chart at version `26.1.1`.

## What this blueprint is optimizing for

- **AKS AVM baseline** for cluster creation
- **Terraform and Bicep** wrappers side by side
- **Internal-only listener exposure** by default
- **Premium SSD-backed PVCs** and dedicated broker placement
- **TechCommunity-ready blog content** aligned to the implementation assets in [`blogs/redpanda`](../../../blogs/redpanda)

## Why this is not a typical AKS microservice

Most AKS application workloads are stateless `Deployment`s that can restart almost anywhere and rely on an external data store for durability. Redpanda is different:

- brokers run as a **`StatefulSet`**, not a generic stateless deployment
- each broker owns a **PersistentVolumeClaim (PVC)** and Azure Disk for log segments
- one broker per dedicated node is the starting point, not an optimization
- listener design matters because clients depend on stable **advertised addresses**
- Redpanda requires **x86_64 CPUs with SSE4.2 support**; unsupported node families fail at runtime

Those storage, CPU, and networking constraints are why this blueprint emphasizes `systempool` + `rpbroker`, `managed-csi-premium`, hard anti-affinity, and internal-only listeners from the start.

## Recommended starting pattern

| Layer | Recommendation | Why |
| --- | --- | --- |
| AKS baseline | Shared AVM wrapper | Keeps cluster creation consistent across workloads |
| System pool | `systempool` for cert-manager and AKS add-ons | Keeps broker nodes focused on streaming traffic |
| Broker pool | Dedicated `rpbroker` user pool with 3 nodes | Lets the 3-broker StatefulSet land one broker per node |
| Helm release | `redpanda/redpanda` chart `26.1.1` | Pins the runtime shape and chart behavior |
| Service exposure | Internal only (`external.enabled: false`) | Avoids unstable advertised-listener design until the network plan is ready |
| TLS | cert-manager backed and enabled by default | Encrypts internal traffic without shipping repo secrets |
| Authentication | SASL left off in starter values | Keeps the repo secret-free; enable before production |
| Persistent storage | `managed-csi-premium`, 256 GiB per broker | Durable SSD-backed PVCs with expansion support |
| Tiered storage | Disabled in checked-in values | Turn on later with Azure Blob + managed identity, never shared keys |

## Blueprint contents

- `docs/architecture.md`
- `docs/portal-deployment.md`
- `docs/az-cli-deployment.md`
- `docs/operations.md`
- `infra/terraform`
- `infra/bicep`
- `kubernetes/helm`
- `kubernetes/manifests`

## Standard release name

The workload guidance assumes the Helm release name `redpanda`. The checked-in values also set `fullnameOverride: redpanda` so service names stay stable for the docs and validation commands.

## Scope of the current implementation

This blueprint now includes:

- a documented target architecture for AKS
- concrete Terraform and Bicep wrappers for `systempool` + `rpbroker`
- a pinned Helm values file for a three-broker cluster
- namespace and storage class manifests
- a publication-ready blog package

It intentionally keeps two items out of the default install path:

- external listeners, because broker advertised-address design is environment specific
- tiered storage, because the Azure Blob identity and RBAC shape should be validated per environment and must use managed identity rather than shared keys
