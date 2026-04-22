# Running Apache Airflow on AKS with dedicated schedulers, workers, and an internal-only UI

**Publication target:** Microsoft TechCommunity > Azure > Linux and Open Source Blog

## Summary

Apache Airflow is often shown as a single UI and a quick Helm install. That framing misses what actually matters on AKS: the scheduler, API server, webserver, triggerer, Celery workers, metadata database, Redis broker, and the way DAGs are distributed to all of them.

This post walks through a starter blueprint for Airflow 3.2.0 on Azure Kubernetes Service (AKS) using the official Airflow Helm chart 1.21.0, a dedicated `airflow` AKS node pool, internal-only UI exposure, and checked-in Terraform, Bicep, Helm, and operations guidance.

## Why Airflow on AKS is not just another web app

This is the key AKS design point: **Airflow is not a single stateless frontend deployment**.

A useful Airflow environment on AKS includes:

- a scheduler that evaluates DAGs and task dependencies
- a webserver for human operators
- an API server for Airflow 3 control-plane traffic
- a triggerer for deferred tasks
- Celery workers that execute user code
- PostgreSQL for metadata
- Redis for Celery message transport
- a DAG distribution strategy that keeps every pod in sync

That is a very different shape from a typical microservice that can be summarized as `Deployment + Service + external database`.

## What the repo now provides

The Airflow workload in this repo is now organized around five concrete building blocks:

1. AKS AVM-based Terraform and Bicep wrappers under `workloads/orchestration/apache-airflow/infra`
2. Airflow architecture, portal, CLI, and operations guidance under `workloads/orchestration/apache-airflow/docs`
3. Helm values and namespace assets under `workloads/orchestration/apache-airflow/kubernetes`
4. a starter node-pool layout that uses a dedicated `airflow` AKS user pool
5. publish-ready blog assets under `blogs/apache-airflow`

## The target AKS pattern

The blueprint uses these opinions by default:

| Layer | Recommendation | Why |
| --- | --- | --- |
| AKS baseline | Shared AVM wrapper | Keeps cluster creation consistent across workloads |
| Workload placement | Dedicated `airflow` node pool with 3 nodes | Isolates orchestration traffic and starter stateful dependencies |
| Executor | `CeleryExecutor` | Makes worker scale-out explicit |
| DAG distribution | `git-sync` | Gives every Airflow pod the same DAG set |
| Metadata DB | Bundled PostgreSQL | Keeps the starter runnable without an extra managed service |
| Broker | Bundled Redis | Makes Celery execution concrete immediately |
| UI exposure | Internal Azure load balancer | Keeps the UI private by default |

The important AKS takeaway is that DAG distribution and worker isolation are first-class deployment concerns. Those do not show up in the same way for a stateless REST service.

## Why the dedicated node pool matters

The checked-in infrastructure creates a user pool named `airflow` with three nodes and a `dedicated=airflow:NoSchedule` taint. That keeps the scheduler, triggerer, workers, and starter PostgreSQL and Redis services away from unrelated application pods.

Three nodes is a practical starter choice because it leaves room for:

- two schedulers
- two webservers
- two triggerers
- multiple workers
- rolling updates without immediately exhausting placement options

## DAG delivery is part of the platform design

One of the easiest mistakes in Kubernetes Airflow deployments is to focus only on Helm and forget DAG delivery.

The repo uses `git-sync` in the checked-in values so the control plane and worker pods all see the same DAG tree. That keeps the starter concrete while leaving room to move later to a private Git repo or a more controlled artifact flow.

## Internal-only access by default

The Airflow web UI is configured as an internal Azure load balancer. That is a better default than publishing the UI publicly, especially when the platform still uses starter credentials and chart-managed dependencies.

Operators can still validate the UI with `kubectl port-forward`, but the blueprint starts private and lets teams open access deliberately later.

## Bundled PostgreSQL and Redis: acceptable starter scope, not the final answer

The Airflow chart-managed PostgreSQL and Redis services are acceptable for a starter blueprint because they make the repo runnable without introducing more Azure dependencies. The docs are explicit about the scope boundary, though:

- PostgreSQL is the metadata source of truth and needs backup planning
- Redis is a queue dependency, not an optional extra
- both services still need PVC-backed durability on AKS
- larger environments should usually move those dependencies out of the chart

## Security and Azure integration notes

The repo avoids committing fake passwords and disables the chart’s default admin-user creation flow. Runtime secrets are created with `kubectl create secret generic`, and the first admin user is created after the chart is installed.

The starter also does **not** wire Azure Storage into the deployment. If you extend the design for remote logging or DAG storage, keep the same repo rule: use managed identity-based access rather than shared keys.

## Closing thought

Airflow on AKS becomes much easier to operate when the repository makes the platform shape explicit: multiple control-plane components, worker isolation, stateful dependencies, and a real DAG distribution story.

That is what this blueprint now provides. It is not pretending to be a one-click production platform, but it is a credible starter that a platform team can evolve without throwing away the first implementation.
