# Apache Superset architecture notes

Superset on AKS is a BI control plane with a web tier, async workers, and stateful dependencies. Treat it differently from a single frontend deployment.

## Why this workload needs a different AKS design

Superset's data exploration UI is only one part of the system. A healthy deployment depends on:

- web pods that serve the UI and REST API
- Celery workers that run async SQL Lab and background tasks
- the `superset-init-db` job that upgrades the metadata schema and initializes roles
- PostgreSQL for metadata, users, dashboards, datasets, and saved queries
- Redis for cache and Celery message transport
- network paths from Superset to external query engines and data sources

## Recommended reference architecture

```text
+-------------------------------------------------------------------+
| AKS cluster                                                       |
|                                                                   |
|  systempool                                                       |
|   - AKS add-ons                                                   |
|                                                                   |
|  superset user pool                                               |
|   - superset web deployment (2 replicas)                          |
|   - superset worker deployment (2 replicas)                       |
|   - superset-init-db hook job during installs and upgrades        |
|   - chart-managed PostgreSQL with Premium SSD PVC                 |
|   - chart-managed Redis with Premium SSD PVC                      |
|                                                                   |
|  Internal BI access                                               |
|   - Service: superset                                             |
|   - Azure internal LoadBalancer only                              |
|                                                                   |
|  External data platforms                                          |
|   - Trino, Spark, Synapse, Snowflake, PostgreSQL, other SQL       |
|     engines reached through SQLAlchemy connectors                 |
+-------------------------------------------------------------------+
```

## Design decisions

| Area | Recommendation | Notes |
| --- | --- | --- |
| Cluster baseline | Use AKS AVM wrappers | Keeps the AKS layer consistent across blueprints |
| Workload placement | Dedicated `superset` pool with 3 nodes | Leaves headroom for web pods, workers, Redis, PostgreSQL, and upgrade jobs |
| UI exposure | Internal load balancer | Keeps the BI surface private by default |
| Async execution | Separate Celery workers from the web tier | Prevents long-running queries from competing directly with the UI |
| Metadata DB | Chart-managed PostgreSQL for the starter | Acceptable scope boundary as long as backups and growth are reviewed |
| Cache and queue | Chart-managed Redis for the starter | Required for cache behavior and worker messaging |
| Init and migrations | Treat `superset-init-db` as a first-class health check | The rollout is not healthy until the hook job succeeds |
| Data-source connectivity | Create connections after install | Superset needs outbound reachability and runtime secrets for target systems |
| Azure Storage integrations | Keep them out of the starter and use workload identity later | Do not introduce shared keys or account-key secrets |

## AKS-specific guidance

### 1. Dedicated node pool

The checked-in IaC provisions a dedicated `superset` user pool with three nodes and a `dedicated=superset:NoSchedule` taint. The Helm values pin the web tier, Celery workers, PostgreSQL, and Redis to that pool. Three nodes leave room for two web pods, two worker pods, PVC-backed dependencies, and rolling upgrades without immediately exhausting placement options.

### 2. Migrations are part of the deployment

The Helm chart's hook job runs `superset db upgrade` and `superset init`. Unlike a stateless deployment, you need `kubectl get jobs` and `kubectl logs job/superset-init-db` in every rollout review. If that job fails, the UI may still start, but the environment is not actually ready.

### 3. Metadata and cache are stateful even when the UI is not

The web and worker pods are replaceable. PostgreSQL and Redis are not. The starter therefore uses `managed-csi-premium` PVCs for both dependencies and treats the metadata database as the source of truth for dashboards, saved queries, users, and role mappings.

### 4. Internal-only access is the safer default

The checked-in service annotations keep Superset behind an Azure internal load balancer and leave ingress disabled. Operators can still use `kubectl port-forward` for validation, but the blueprint does not assume the BI UI should be internet-reachable.

### 5. Data-source secrets and Azure integrations stay external

The workload does not commit database passwords, datasource passwords, or the Superset Flask `SECRET_KEY`. Runtime secrets are created outside Git as `superset-env` and `superset-postgresql-auth`. If you later add Azure Storage-backed exports, logs, or artifacts, bind workload identity to the `superset` service account instead of storing storage account keys.

Celery beat and Flower stay disabled in the starter because scheduled reports and queue-monitoring UIs bring extra browser, SMTP, and notification dependencies that deserve separate design review.

## Capacity starter values

| Component | Starter replicas | Requests | Notes |
| --- | --- | --- | --- |
| Web tier | 2 | 500m CPU / 1 GiB | Operator-facing UI and REST API |
| Celery workers | 2 | 1 CPU / 2 GiB | SQL Lab async work and background tasks |
| Init / migration job | 1 job per install or upgrade | 500m CPU / 1 GiB | Must complete before the rollout is healthy |
| PostgreSQL | 1 | 500m CPU / 1 GiB plus 16 GiB PVC | Metadata durability |
| Redis | 1 | 250m CPU / 512 MiB plus 8 GiB PVC | Cache and Celery transport |

These are starter values for evaluation and smaller team environments. Scale the `superset` node pool, worker count, and metadata services based on query concurrency, dashboard traffic, retained metadata, and the number of external data sources.
