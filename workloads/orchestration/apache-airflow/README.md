# Apache Airflow on AKS

This blueprint turns the repository's Airflow stub into a concrete starter for **Apache Airflow 3.2.0** on AKS using the official **Apache Airflow Helm chart 1.21.0**.

## What this blueprint is optimizing for

- **AKS AVM baseline** for the cluster foundation
- **Dedicated `airflow` user pool** with three nodes for orchestration components and starter dependencies
- **Internal-only web UI** by default through an Azure internal load balancer
- **Concrete starter dependencies** with the chart-managed PostgreSQL metadata database and Redis broker
- **Git-driven DAG distribution** with `git-sync` so the scheduler, webserver, triggerer, and workers see the same DAG set
- **TechCommunity-ready blog content** aligned to the implementation assets in [`blogs/apache-airflow`](../../../blogs/apache-airflow)

## Why this is not a typical AKS microservice

Airflow is not a single stateless web deployment.

- the **scheduler** decides when DAG runs and tasks should start
- the **webserver** exposes the UI and operator workflows
- the **API server** backs Airflow 3 control-plane requests and CLI traffic
- the **triggerer** keeps deferred and event-driven tasks alive without pinning worker slots
- **Celery workers** execute tasks and can be restarted independently of the control plane
- the **metadata database** stores state for DAG runs, tasks, connections, variables, and migrations
- the **Redis broker** carries Celery work between the scheduler and workers
- **DAG files** have to be delivered consistently to multiple pods, which is why this blueprint uses `git-sync`

A normal stateless app can often be summarized as “deployment + ingress + database”. Airflow on AKS needs a multi-component control plane, stateful dependencies, and explicit DAG distribution.

## Recommended starting pattern

| Layer | Recommendation | Why |
| --- | --- | --- |
| AKS baseline | Shared AVM wrapper | Keeps cluster creation consistent with the rest of the repo |
| Workload placement | Dedicated `airflow` AKS user pool | Isolates orchestration traffic and starter stateful dependencies from unrelated workloads |
| Executor | `CeleryExecutor` | Keeps scheduler, triggerer, and worker roles explicit on AKS |
| DAG distribution | `git-sync` sidecar | Ensures every Airflow component sees the same DAG tree |
| Metadata DB | Bundled PostgreSQL for the starter | Makes the blueprint runnable without introducing extra Azure database dependencies |
| Broker | Bundled Redis for the starter | Keeps Celery message transport concrete from day one |
| UI exposure | Internal Azure load balancer | Keeps the web UI private by default |
| Persistent storage | `managed-csi-premium` for PostgreSQL and Redis | Gives the starter stateful tiers durable AKS-backed storage |

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
- `kubernetes/helm/airflow-values.yaml`
- `kubernetes/helm/README.md`
- `kubernetes/manifests/managed-csi-premium-storageclass.yaml`
- `kubernetes/manifests/namespace.yaml`
- `kubernetes/manifests/README.md`

## Standard release and namespace

The checked-in commands and connection-secret examples assume:

- Helm release: `airflow`
- Kubernetes namespace: `airflow`

Keeping those names stable makes the bundled PostgreSQL and Redis service discovery predictable.

The documented deployment flows apply both bootstrap manifests before Helm installation so the `airflow` namespace exists and the bundled PostgreSQL and Redis PVCs can bind against `managed-csi-premium` on a fresh AKS cluster.

## Scope boundary

This starter deliberately uses the chart-managed PostgreSQL database and Redis broker so the blueprint is runnable without extra platform services. It does **not** pre-wire a private DAG repository, remote task logging, or an external database tier. When you evolve the design, keep Azure Well-Architected guidance in mind and use managed identity-based access for any Azure Storage integration instead of shared keys.
