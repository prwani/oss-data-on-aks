# Apache Airflow architecture notes

Airflow on AKS is a platform workload with a distributed control plane, queue-driven workers, and stateful dependencies.

## Why this workload needs a different AKS design

Airflow is not “one web app with a backing database”. A healthy deployment depends on several cooperating services:

- the scheduler constantly evaluates DAGs and task dependencies
- the API server and webserver expose operator and automation workflows
- the triggerer holds deferred tasks until their events fire
- Celery workers execute user code and scale independently of the control plane
- PostgreSQL persists metadata and migration state
- Redis brokers Celery work between the scheduler and workers

## Recommended reference architecture

```text
+-------------------------------------------------------------------+
| AKS cluster                                                       |
|                                                                   |
|  systempool                                                       |
|   - AKS add-ons                                                   |
|                                                                   |
|  airflow user pool                                                |
|   - airflow-api-server (2 replicas)                               |
|   - airflow-webserver (2 replicas)                                |
|   - airflow-scheduler (2 replicas)                                |
|   - airflow-triggerer (2 replicas)                                |
|   - airflow Celery workers (3 replicas)                           |
|   - airflow migration job and helper pods                         |
|   - chart-managed PostgreSQL and Redis                            |
|                                                                   |
|  DAG distribution                                                 |
|   - git-sync sidecars pull a shared DAG repo into each pod        |
|                                                                   |
|  Airflow UI                                                       |
|   - internal Azure LoadBalancer only                              |
|                                                                   |
|  Metadata and broker                                              |
|   - PostgreSQL PVC on managed-csi-premium                         |
|   - Redis PVC on managed-csi-premium                              |
+-------------------------------------------------------------------+
```

## Design decisions

| Area | Recommendation | Notes |
| --- | --- | --- |
| Cluster baseline | Use AKS AVM wrappers | Keeps the AKS layer consistent across blueprints |
| Workload placement | Dedicated `airflow` pool with 3 nodes | Gives scheduler, triggerer, workers, and starter dependencies predictable capacity |
| Executor | `CeleryExecutor` | Matches the need for long-running workers plus separate scheduling logic |
| DAG delivery | `git-sync` from Git | Avoids baking DAGs into the image while keeping delivery concrete |
| UI exposure | Internal load balancer | Keeps the operator surface private by default |
| Metadata DB | Chart-managed PostgreSQL for the starter | Acceptable for a blueprint as long as the scope boundary is explicit |
| Broker | Chart-managed Redis for the starter | Good enough for the first runnable pattern |

## AKS-specific guidance

### 1. Dedicated node pool

The checked-in IaC provisions a dedicated `airflow` user pool with three nodes and a `dedicated=airflow:NoSchedule` taint. The Helm values pin the core Airflow components, bundled PostgreSQL, and Redis to that pool.

### 2. DAG distribution is an operational concern

This starter uses `git-sync` so the scheduler, webserver, triggerer, and workers all see the same DAG tree. That is an AKS-specific concern because the pods run on different nodes and can be rescheduled independently.

### 3. Persistent storage belongs to the dependencies

Airflow itself is mostly stateless, but the bundled PostgreSQL and Redis services are not. The starter therefore uses Premium SSD-backed CSI volumes for those components while leaving task logs on the default ephemeral path.

### 4. Internal-only access by default

The web UI uses an internal Azure load balancer. Operators can also use `kubectl port-forward` during validation, but the blueprint does not publish the UI to the internet by default.

### 5. Storage integrations must use managed identity

The checked-in starter does not enable remote logging or DAG storage in Azure Storage. If you add Azure Blob or Data Lake Storage later, use workload identity or another managed identity-based flow instead of account keys or SAS-only patterns.

## Capacity starter values

| Component | Starter replicas | Requests | Notes |
| --- | --- | --- | --- |
| API server | 2 | 500m CPU / 1 GiB | Keeps Airflow 3 control-plane access redundant |
| Webserver | 2 | 500m CPU / 1 GiB | Internal operator-facing UI |
| Scheduler | 2 | 1 CPU / 2 GiB | Scheduler HA for DAG parsing and orchestration |
| Triggerer | 2 | 500m CPU / 1 GiB | Needed for deferrable tasks |
| Celery workers | 3 | 1 CPU / 2 GiB | Starter footprint for real task execution |
| PostgreSQL | 1 | chart default plus 16 GiB PVC | Metadata durability |
| Redis | 1 | chart default plus 8 GiB PVC | Celery broker durability |

These are starter values for evaluation and small team environments. Scale them based on task concurrency, DAG parsing cost, scheduler latency, and expected worker runtime.
