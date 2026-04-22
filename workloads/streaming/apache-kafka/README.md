# Apache Kafka on AKS

This blueprint is the repository's Kafka-specific starter for running **Apache Kafka 4.0** on AKS with **AKS AVM** as the shared cluster baseline and the **Bitnami Kafka chart pinned to 32.4.4** in **KRaft** mode.

## What this blueprint is optimizing for

- **AKS AVM baseline** for the cluster foundation
- **one dedicated AKS user pool named `kafka`** with 3 nodes
- **3 KRaft controllers and 3 brokers** with ZooKeeper removed
- **Terraform and Bicep** entry points side by side
- **portal-first** and **`az` CLI-first** operator journeys
- **internal-only Kafka exposure by default**
- **stateful workload guidance** for PVCs, listener topology, retention planning, and upgrades
- **TechCommunity-ready blog content** aligned to [`blogs/apache-kafka`](../../../blogs/apache-kafka)

## Why this is not a typical AKS microservice

Most AKS application workloads are stateless `Deployment`s behind one service endpoint. Kafka is different:

- **KRaft controllers** keep cluster metadata and quorum state
- **brokers** persist partition logs to per-pod PVCs
- **listener topology** matters because clients do not just talk to one HTTP endpoint; they need broker-specific advertised addresses
- **storage math** matters because replication factor and free-space headroom reduce usable retention capacity
- **stateful upgrades** depend on controller quorum and in-sync replica health, not just pod readiness

That is why the checked-in blueprint emphasizes a dedicated user pool, Premium SSD-backed PVCs, internal-only service exposure, and explicit day-2 runbooks from the start.

## Recommended starting pattern

| Layer | Recommendation | Why |
| --- | --- | --- |
| AKS baseline | Shared AVM wrapper | Keeps cluster creation consistent across workloads |
| System pool | `systempool` with 1 node | Hosts AKS add-ons separately from Kafka data plane pods |
| Kafka pool | Dedicated `kafka` user pool with 3 nodes | Lets the default controller and broker anti-affinity land cleanly |
| Controller tier | 3 controller-only pods | Protects KRaft quorum and metadata durability |
| Broker tier | 3 broker-only pods | Separates log I/O from controller responsibilities |
| Persistent storage | `managed-csi-premium` | Sensible default for durable SSD-backed Azure Disks |
| Client exposure | `ClusterIP` only | Keeps bootstrap access inside the cluster by default |
| Recovery posture | Preserve PVCs and `kafka-kraft`; use cross-cluster replication for DR | Kafka durability is broader than pod restarts |

## Azure-specific note on storage integrations

This starter blueprint does **not** create an Azure Storage account by default because Kafka's primary data path lives on broker PVCs backed by Azure Disks. If you later add Kafka Connect sinks, archival, or tiered-storage-adjacent integrations that use Azure Storage, use **AKS Workload Identity and managed identity-based authentication only**.

## Blueprint contents

- `docs/architecture.md`
- `docs/portal-deployment.md`
- `docs/az-cli-deployment.md`
- `docs/operations.md`
- `infra/terraform/main.tf`
- `infra/terraform/terraform.tfvars.example`
- `infra/terraform/variables.tf`
- `infra/terraform/outputs.tf`
- `infra/bicep/main.bicep`
- `infra/bicep/main.bicepparam`
- `kubernetes/helm`
- `kubernetes/manifests`
- `scripts/az-cli`

## Standard release name

The workload guidance assumes a single Helm release named `kafka` in the `kafka` namespace. The checked-in service names, StatefulSet names, and operational commands line up with that release contract.

## Scope of the current implementation

This blueprint now includes:

- a documented AKS target architecture for Kafka in KRaft mode
- concrete Terraform and Bicep wrappers that provision `systempool` plus a dedicated `kafka` node pool
- a pinned Helm values file for Bitnami Kafka chart `32.4.4`
- namespace and Premium CSI storage class manifests
- portal and CLI deployment flows with validation commands
- workload-specific operations guidance covering quorum, PVCs, listeners, retention, and upgrades
- a blog package ready for TechCommunity editing and publication

It does **not** claim to solve every production hardening task end to end. Cross-region disaster recovery, external client endpoint design, and environment-specific observability integrations should still be validated for the target platform.
