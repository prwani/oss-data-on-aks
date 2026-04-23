# Apache Flink on AKS

This blueprint provides a concrete starter for **Apache Flink 1.20.1** on AKS using the official **Apache Flink Kubernetes Operator 1.10.0**.

## What this blueprint is optimizing for

- **AKS AVM baseline** for repeatable AKS cluster creation
- **Terraform and Bicep** wrappers side by side
- **A dedicated `flink` AKS user pool with 3 nodes** for JobManager and TaskManager placement
- **Official Flink Kubernetes Operator** with a pinned Helm values file and a real `FlinkDeployment` sample
- **Built-in operator autoscaling** that adjusts TaskManager parallelism and pod count based on workload backpressure
- **AKS cluster autoscaler** documented as a post-deployment step for node-level elasticity
- **AKS-first operational guidance** for job lifecycle, checkpointing, high availability, and autoscaler tuning

## Why this is not a typical AKS microservice

Flink on AKS is a distributed stream and batch processing engine:

- jobs are declared as **`FlinkDeployment` custom resources**, not always-on `Deployment`s with fixed replica counts
- the **JobManager** coordinates execution and manages checkpoints, while **TaskManagers** execute the dataflow graph
- **TaskManager pods scale with parallelism**, so the operator may add or remove pods based on backpressure metrics
- **checkpointing and savepoints** are part of the runtime contract and determine recovery and upgrade behavior
- **high availability** requires a durable storage directory and Kubernetes-native leader election
- validation starts with **job status, checkpoint health, and TaskManager availability**, not just a service endpoint

A normal stateless application can be summarized as "deployment + service + database." Flink on AKS needs an operator, namespaced RBAC, a dedicated compute pool, checkpoint storage, and explicit autoscaling configuration.

## Recommended starting pattern

| Layer | Recommendation | Why |
| --- | --- | --- |
| AKS baseline | Shared AVM wrapper | Keeps cluster creation consistent across workloads |
| Operator control plane | Helm release `flink-kubernetes-operator` in namespace `flink-operator` | Separates the operator from job resources |
| Workload namespace | Namespace `flink` with namespaced service account and RBAC | Makes job permissions explicit |
| Compute placement | Dedicated `flink` pool with 3 `Standard_D8ds_v5` nodes | Gives JobManager and TaskManagers headroom for CPU, memory, and local state |
| Deployment model | `FlinkDeployment` resources in Application mode | Each job gets its own isolated Flink cluster |
| High availability | Kubernetes-native HA with leader election via ConfigMaps | Avoids ZooKeeper dependency |
| Checkpoint storage | Local filesystem for starter; ADLS Gen2 with workload identity for production | Keeps the starter self-contained while documenting the production path |
| Autoscaling | Flink operator autoscaler for job-level scaling; AKS cluster autoscaler for node-level elasticity | Two-layer approach keeps job scheduling and node provisioning independent |
| Access path | Flink Web UI via `kubectl port-forward` | Avoids treating Flink like a permanent internet-facing service |
| Azure Storage integration | Add ADLS Gen2 with workload identity and managed identity auth only | Keeps shared keys out of the blueprint |

## Blueprint contents

- `docs/architecture.md`
- `docs/portal-deployment.md`
- `docs/az-cli-deployment.md`
- `docs/operations.md`
- `infra/terraform/main.tf`
- `infra/terraform/variables.tf`
- `infra/terraform/outputs.tf`
- `infra/terraform/terraform.tfvars.example`
- `infra/bicep/main.bicep`
- `infra/bicep/main.bicepparam`
- `kubernetes/helm/operator-values.yaml`
- `kubernetes/helm/README.md`
- `kubernetes/manifests/README.md`
- `kubernetes/manifests/namespace.yaml`
- `kubernetes/manifests/flink-serviceaccount-rbac.yaml`
- `kubernetes/manifests/flink-word-count.yaml`
- `scripts/az-cli/README.md`

## Standard release names and namespaces

The checked-in guidance assumes:

- operator Helm release: `flink-kubernetes-operator`
- operator namespace: `flink-operator`
- workload namespace: `flink`
- workload service account: `flink`

Keeping those names stable makes the operator install, FlinkDeployment manifests, and validation commands line up without extra translation.

## Autoscaling overview

This blueprint configures two independent autoscaling layers:

1. **Flink operator autoscaler** (part of deployment): the Flink Kubernetes Operator monitors source backpressure and TaskManager busy time, then adjusts job parallelism and TaskManager pod count automatically. This is configured directly in the `FlinkDeployment` resource.

2. **AKS cluster autoscaler** (post-deployment): when the operator requests more TaskManager pods than the fixed node pool can schedule, the AKS cluster autoscaler adds nodes. Enable this on the `flink` pool after deployment to support elastic scaling beyond the initial 3-node capacity.

See `docs/architecture.md` for design details and `docs/operations.md` for tuning guidance.

## Scope boundary

This starter keeps the runtime self-contained around the official operator and a real WordCount streaming job. It does **not** pre-wire ADLS Gen2, Kafka connectors, savepoint-based upgrades, or multi-tenant job isolation. Those integrations should be added only after the target environment's identity, networking, and data-governance boundaries are clear.

When you extend the blueprint to ADLS Gen2, follow the repository rule: use AKS workload identity with managed identity-based auth and never fall back to storage account shared keys.
