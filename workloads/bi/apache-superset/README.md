# Apache Superset on AKS

This blueprint turns the repository's Superset stub into a concrete starter for **Apache Superset 5.0.0** on AKS using the official **Superset Helm chart 0.15.4**.

## What this blueprint is optimizing for

- **AKS AVM baseline** for the cluster foundation
- **Dedicated `superset` user pool** with three nodes for the web tier, Celery workers, and starter dependencies
- **Internal-only Superset UI** by default through an Azure internal load balancer
- **Concrete starter dependencies** with chart-managed PostgreSQL metadata storage and Redis for cache and Celery
- **Secret-driven bootstrap** using external Kubernetes secrets instead of committed admin passwords or fake keys
- **TechCommunity-ready blog content** aligned to the implementation assets in [`blogs/apache-superset`](../../../blogs/apache-superset)

## Why this is not a typical AKS microservice

Superset is not a single stateless frontend deployment.

- the **web nodes** expose the UI and REST APIs
- **Celery workers** handle SQL Lab async execution and other background work
- the **metadata database** stores users, roles, dashboards, datasets, saved queries, and migration state
- **Redis** backs cache and Celery messaging
- the **`superset-init-db` job** runs schema migrations and `superset init` as part of every install or upgrade
- Superset connects to **external data platforms** such as Trino, Spark, Synapse, Snowflake, or PostgreSQL, so the AKS workload owns the control plane even when the analytics data lives elsewhere

A normal stateless app can often be summarized as “deployment + service + database”. Superset on AKS needs a UI tier, async workers, a metadata control plane, and explicit runtime secret handling.

## Recommended starting pattern

| Layer | Recommendation | Why |
| --- | --- | --- |
| AKS baseline | Shared AVM wrapper | Keeps cluster creation consistent with the rest of the repo |
| Workload placement | Dedicated `superset` AKS user pool | Isolates BI traffic, worker bursts, and starter stateful dependencies |
| Web tier | 2 Superset web replicas | Keeps the UI available during rolling updates |
| Async execution | 2 Celery worker replicas | Gives SQL Lab and background tasks a separate scale unit |
| Init and migrations | Keep the chart hook job enabled | Makes database schema state part of the deployment contract |
| Metadata DB | Chart-managed PostgreSQL for the starter | Keeps the blueprint runnable without an extra Azure database dependency |
| Cache and queue | Chart-managed Redis for the starter | Makes Celery and cache behavior concrete from day one |
| UI exposure | Internal Azure load balancer | Keeps the operator surface private by default |

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
- `kubernetes/helm/superset-values.yaml`
- `kubernetes/helm/README.md`
- `kubernetes/manifests/namespace.yaml`
- `kubernetes/manifests/README.md`

## Standard release and namespace

The checked-in commands and secret names assume:

- Helm release: `superset`
- Kubernetes namespace: `superset`

Keeping those names stable makes the metadata database and Redis service discovery predictable.

## Scope boundary

This starter deliberately uses the chart-managed PostgreSQL database and Redis service so the blueprint stays runnable on a fresh AKS cluster. It does **not** pre-wire SSO, SMTP, scheduled reports, an external metadata database, or Azure Storage-based exports. Celery beat and Flower stay disabled until you intentionally add scheduled reports or queue monitoring. When you extend the design, keep Azure Well-Architected guidance in mind and use workload identity or another managed identity-based flow for any Azure Storage integration instead of shared keys.
