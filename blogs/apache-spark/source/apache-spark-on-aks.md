# Running Apache Spark on AKS with the official Spark Kubernetes Operator and a dedicated job pool

**Publication target:** Microsoft TechCommunity > Azure > Linux and Open Source Blog

## Summary

Apache Spark is easy to demo on Kubernetes, but a reusable AKS blueprint needs more than a single `spark-submit` example. Spark jobs are short-lived, the driver creates the executors at runtime, and shuffle plus spill can overwhelm generic nodes quickly.

This post walks through a starter blueprint for **Apache Spark 4.1.1** on **Azure Kubernetes Service (AKS)** using the official **Spark Kubernetes Operator chart 1.6.0**, a dedicated `spark` user pool, explicit namespaced RBAC, and checked-in Terraform, Bicep, Helm, and operations guidance.

## Why Spark on AKS is not just another microservice

This is the key AKS design point: **Spark is not a long-running stateless microservice**.

A useful Spark environment on AKS includes:

- an operator that watches `SparkApplication` resources
- a driver pod that exists only for the lifetime of a job
- executor pods that scale up and disappear with the workload
- namespaced RBAC so the driver can create executors and related resources
- explicit local scratch space for shuffle and spill

That is a very different shape from a normal web API that can be summarized as `Deployment + Service + external database`.

## What the repo now provides

The Spark workload in this repo is now organized around five practical building blocks:

1. AKS AVM-based Terraform and Bicep wrappers under `workloads/distributed-processing/apache-spark/infra`
2. Spark architecture, portal, CLI, and operations guidance under `workloads/distributed-processing/apache-spark/docs`
3. operator Helm values and Spark manifests under `workloads/distributed-processing/apache-spark/kubernetes`
4. a starter node-pool layout with a dedicated `spark` AKS user pool
5. publish-ready blog assets under `blogs/apache-spark`

## The target AKS pattern

The blueprint uses these opinions by default:

| Layer | Recommendation | Why |
| --- | --- | --- |
| AKS baseline | Shared AVM wrapper | Keeps cluster creation consistent across workloads |
| Operator control plane | `spark-operator` namespace on the system pool | Keeps reconciliation stable even when jobs are busy |
| Workload placement | Dedicated `spark` pool with 3 nodes | Isolates driver and executor pressure from AKS add-ons |
| Submission model | `SparkApplication` CRs | Matches the operator lifecycle instead of pretending Spark is a permanent service |
| Local scratch space | `emptyDir` at `/var/data/spark-local-dir` | Makes shuffle and spill explicit on AKS |
| Access path | `kubectl port-forward` to the driver UI while it runs | Keeps Spark internal by default |

The important AKS takeaway is that **driver and executor lifecycle plus local spill are first-class platform concerns**. Those do not show up in the same way for a stateless REST service.

## Why the dedicated `spark` node pool matters

The checked-in infrastructure creates a user pool named `spark` with three `Standard_D8ds_v5` nodes and the taint `dedicated=spark:NoSchedule`. That keeps Spark execution away from the system pool and gives the job access to more CPU, memory, and local temp disk headroom.

The `ds` SKU choice is deliberate. Spark on AKS can consume node-local storage quickly through shuffle and spill, so the pool needs more than just enough CPU to start the containers.

## The job lifecycle is the platform contract

The sample application in the repo is a real `spark-pi` `SparkApplication`, not a stub. It pins Spark to `4.1.1`, uses the official image `apache/spark:4.1.1-scala`, and names the driver pod `spark-pi-driver` so the validation flow is predictable.

The blueprint also keeps secondary resources around for ten minutes after completion. That gives operators a short inspection window for logs and pod details without leaving the namespace cluttered forever.

## Shuffle and spill belong in the design, not the footnotes

One of the easiest mistakes in early Spark-on-Kubernetes deployments is to focus on the operator and forget local storage behavior.

The repo sets `spark.local.dir` explicitly and mounts `emptyDir` volumes for driver and executor pods. That makes the trade-off visible:

- fast local scratch space is good for batch execution
- node ephemeral storage pressure becomes an operational signal
- tiny shared system nodes are the wrong default for serious Spark jobs

## Security and Azure integration notes

The starter does **not** commit secrets or fake Azure Storage credentials. It also does **not** create a demo storage account just to make the docs look complete.

That is intentional. When you extend Spark on AKS to ADLS Gen2, event logs, or checkpoint output, the repository standard still applies: use workload identity with managed identity-based authentication and do not fall back to storage account shared keys.

## Closing thought

Spark on AKS becomes easier to reason about when the repository makes the real platform shape explicit: an operator, ephemeral drivers and executors, namespaced RBAC, a dedicated batch pool, and visible shuffle plus spill behavior.

That is what this blueprint now provides. It is not pretending to be every possible Spark platform pattern, but it is a credible AKS starter that a platform team can evolve without throwing away the first implementation.
