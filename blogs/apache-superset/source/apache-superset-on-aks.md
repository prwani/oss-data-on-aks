# Running Apache Superset on AKS with Celery workers, metadata state, and an internal-only UI

**Publication target:** Microsoft TechCommunity > Azure > Linux and Open Source Blog

## Summary

Apache Superset is easy to demo as a web UI with a quick Helm command. That shortcut hides what matters on AKS: the web tier, Celery workers, metadata database, Redis, the init and migration job, and the fact that Superset connects out to analytics engines instead of holding the business data itself.

This post walks through a starter blueprint for Superset 5.0.0 on Azure Kubernetes Service (AKS) using the official Superset Helm chart 0.15.4, a dedicated `superset` AKS node pool, internal-only UI exposure, and checked-in Terraform, Bicep, Helm, and operations guidance.

## Why Superset on AKS is not just another web app

This is the AKS design point to keep in view: **Superset is not a single stateless frontend deployment**.

A useful Superset environment on AKS includes:

- web pods for the UI and REST APIs
- Celery workers for async SQL Lab and background tasks
- a metadata PostgreSQL database for users, dashboards, datasets, saved queries, and schema state
- Redis for cache and Celery transport
- a `superset-init-db` job that upgrades the schema and runs `superset init`
- outbound connectivity to external data engines such as Trino, Spark, Synapse, Snowflake, or PostgreSQL

That is very different from a microservice that can be summarized as `Deployment + Service + external database`.

## What the repo now provides

The Superset workload in this repo is now organized around five concrete building blocks:

1. AKS AVM-based Terraform and Bicep wrappers under `workloads/bi/apache-superset/infra`
2. architecture, portal, CLI, and operations guidance under `workloads/bi/apache-superset/docs`
3. Helm values and namespace assets under `workloads/bi/apache-superset/kubernetes`
4. a starter node-pool layout that uses a dedicated `superset` AKS user pool
5. publish-ready blog assets under `blogs/apache-superset`

## The target AKS pattern

The blueprint uses these opinions by default:

| Layer | Recommendation | Why |
| --- | --- | --- |
| AKS baseline | Shared AVM wrapper | Keeps cluster creation consistent across workloads |
| Workload placement | Dedicated `superset` node pool with 3 nodes | Isolates BI traffic, Celery workers, and starter stateful dependencies |
| Web tier | 2 Superset web replicas | Keeps the UI available during upgrades |
| Async execution | 2 Celery workers | Separates long-running query work from the web tier |
| Metadata DB | Bundled PostgreSQL | Keeps the starter runnable without extra Azure database setup |
| Cache and queue | Bundled Redis | Makes Celery and cache behavior concrete immediately |
| UI exposure | Internal Azure load balancer | Keeps the UI private by default |

The important AKS takeaway is that `kubectl get jobs` and `kubectl get pvc` become first-class validation commands. A completed `superset-init-db` job and bound PVCs for PostgreSQL and Redis matter just as much as healthy web pods.

Celery beat and Flower intentionally stay off in the starter. Scheduled reports, screenshot capture, and queue-monitoring UIs are real platform concerns, but they are better added deliberately than hidden inside a default install.

## Why the dedicated node pool matters

The checked-in infrastructure creates a user pool named `superset` with three nodes and a `dedicated=superset:NoSchedule` taint. That keeps the Superset web tier, Celery workers, and starter PostgreSQL/Redis services away from unrelated application pods.

Three nodes is a practical starter choice because it gives room for:

- two web replicas
- two worker replicas
- the migration hook job during upgrades
- PVC-backed Redis and PostgreSQL pods
- rolling updates without immediately exhausting placement options

## Migrations and metadata state are part of the platform design

One of the easiest mistakes in Kubernetes Superset deployments is to focus on the UI and forget the control-plane state.

Superset does not become healthy on AKS just because the `superset` service exists. The init job has to finish, the metadata database has to be reachable, and Redis has to be up before async work behaves correctly. That is why the repo treats the `superset-init-db` job, PostgreSQL PVC, and Redis PVC as explicit deployment assets rather than afterthoughts.

## Internal-only access by default

The Superset service is configured as an internal Azure load balancer. That is a better default than publishing a BI surface publicly, especially while the platform still uses starter chart-managed dependencies and runtime-created admin credentials.

Operators can still use `kubectl port-forward` for validation, but the blueprint starts private and lets teams open access deliberately later.

## No fake secrets in the repo

The repo avoids committing fake admin passwords or fake Flask secret keys. Runtime secrets are created with `kubectl create secret generic` for:

- the PostgreSQL password expected by the chart-managed metadata database
- the `superset-env` secret consumed by the web tier, workers, and init job
- the first admin account, which is created after the chart install with `superset fab create-admin`

That keeps the starter runnable without turning Git into a secret store.

## Azure integration notes

This starter keeps Azure dependencies intentionally light. It does not wire SSO, Azure Storage, or a managed database by default. That is a scope boundary, not a dead end.

If you extend the design later for exports, cached results, or other Azure Storage-backed flows, keep the repo rule intact: use workload identity or another managed identity-based approach instead of storage account keys.

## Closing thought

Superset on AKS becomes much easier to reason about when the repo makes the platform shape explicit: web pods, workers, migration jobs, metadata state, cache state, and private access.

That is what this blueprint now provides. It is not pretending to be a one-click production platform, but it is a credible starter that a platform team can evolve without throwing away the first implementation.
