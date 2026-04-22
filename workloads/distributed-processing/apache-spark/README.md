# Apache Spark on AKS

This blueprint turns the repository's Spark stub into a concrete starter for **Apache Spark 4.1.1** on AKS using the official **Apache Spark Kubernetes Operator Helm chart 1.6.0** (operator app version `0.8.0`).

## What this blueprint is optimizing for

- **AKS AVM baseline** for repeatable AKS cluster creation
- **Terraform and Bicep** wrappers side by side
- **A dedicated `spark` AKS user pool with 3 nodes** for driver and executor placement
- **Official Spark operator flow** with a pinned Helm values file and a real `SparkApplication` sample
- **AKS-first operational guidance** for job lifecycle, shuffle/spill, and ephemeral driver/executor pods
- **TechCommunity-ready blog content** aligned to the implementation assets in [`blogs/apache-spark`](../../../blogs/apache-spark)

## Why this is not a typical AKS microservice

Spark on AKS is not a long-running microservice:

- jobs are declared as **`SparkApplication` custom resources**, not always-on `Deployment`s
- the **driver pod is ephemeral** and creates the executor pods needed for a specific run
- **executors come and go with the workload**, so node placement and cleanup behavior matter more than stable replica counts
- **shuffle, spill, and `spark.local.dir`** use node-local storage and can exhaust small nodes quickly
- validation starts with **SparkApplication state, driver logs, and executor scheduling**, not just a service endpoint

A normal stateless application can often be summarized as “deployment + service + database”. Spark on AKS needs an operator, namespaced RBAC, a dedicated compute pool, and explicit handling for short-lived job resources.

## Recommended starting pattern

| Layer | Recommendation | Why |
| --- | --- | --- |
| AKS baseline | Shared AVM wrapper | Keeps cluster creation consistent across workloads |
| Operator control plane | Helm release `spark-operator` in namespace `spark-operator` | Separates the controller from job resources |
| Workload namespace | Namespace `spark` with namespaced service account and RBAC | Makes driver permissions explicit |
| Compute placement | Dedicated `spark` pool with 3 `Standard_D8ds_v5` nodes | Gives drivers and executors headroom for CPU, memory, and local spill |
| Submission model | `SparkApplication` resources | Matches the operator's lifecycle and status model |
| Local scratch space | `emptyDir` mounted at `/var/data/spark-local-dir` | Keeps shuffle and spill visible in the design |
| Access path | Driver UI via `kubectl port-forward` while the app is alive | Avoids treating Spark like a permanent internet-facing service |
| Azure Storage integration | Add later with workload identity and managed identity auth only | Keeps shared keys out of the blueprint |

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
- `kubernetes/manifests/spark-serviceaccount-rbac.yaml`
- `kubernetes/manifests/spark-pi.yaml`
- `scripts/az-cli/README.md`

## Standard release names and namespaces

The checked-in guidance assumes:

- operator Helm release: `spark-operator`
- operator namespace: `spark-operator`
- workload namespace: `spark`
- workload service account: `spark`

Keeping those names stable makes the operator install, SparkApplication manifests, and validation commands line up without extra translation.

## Scope boundary

This starter keeps the runtime self-contained around the official operator and a real `spark-pi` job. It does **not** pre-wire Azure Storage, event log archival, a Spark History Server, Livy, notebooks, or a multi-tenant scheduler overlay. Those integrations should be added only after the target environment's identity, networking, and data-governance boundaries are clear.

When you extend the blueprint to Azure Storage or ADLS, follow the repository rule: use AKS workload identity with managed identity-based auth and never fall back to storage account shared keys.
