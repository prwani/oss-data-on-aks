# OSS Data on AKS

Reusable starter repository for deploying open-source data and analytics platforms on **Azure Kubernetes Service (AKS)** with **Azure Verified Modules (AVM)** as the infrastructure baseline.

This repository is designed for:

- teams that prefer **Terraform**
- teams that prefer **Bicep**
- operators who start in the **Azure portal**
- operators who prefer **`az` CLI** and automation-first workflows

## Principles

1. **AKS baseline first**: every workload starts from a shared AKS AVM foundation.
2. **Dual IaC paths**: every workload keeps Terraform and Bicep entry points side by side.
3. **Two operator journeys**: every workload gets a portal-oriented path and a CLI-oriented path.
4. **Workload-specific guidance**: platform concerns stay shared; tuning and day-2 operations live with each workload.
5. **Publishable content**: blog assets are packaged for Microsoft TechCommunity submission workflows.

## Initial workload catalog

| Category | Workloads |
| --- | --- |
| Search and analytics | OpenSearch |
| Streaming | Redpanda, Apache Kafka |
| Query engines | Trino |
| OLAP databases | ClickHouse |
| Orchestration | Apache Airflow |
| Distributed processing | Apache Spark |
| BI and semantic access | Apache Superset |

See [`catalog/README.md`](./catalog/README.md) for the current blueprint matrix.

## Repository layout

```text
.
├── blogs/                  # TechCommunity-ready blog source, metadata, and asset manifests
├── catalog/                # High-level inventory of workloads and delivery status
├── docs/                   # Shared platform, operator, and contributor guidance
├── platform/               # Shared AKS AVM baseline for Terraform and Bicep
├── templates/              # Reusable starter files for future workloads
└── workloads/              # Workload blueprints grouped by platform category
```

## Shared guidance

| Need | Start here |
| --- | --- |
| Choose an operator path | [`docs/user-journeys/portal.md`](./docs/user-journeys/portal.md) or [`docs/user-journeys/az-cli.md`](./docs/user-journeys/az-cli.md) |
| Understand the shared AKS baseline | [`docs/platform/architecture.md`](./docs/platform/architecture.md) and [`platform/aks-avm`](./platform/aks-avm) |
| Plan identity, secrets, and service exposure | [`docs/platform/security.md`](./docs/platform/security.md) |
| Plan storage, retention, and backup posture | [`docs/platform/storage.md`](./docs/platform/storage.md) |
| Plan logs, metrics, alerts, and runbooks | [`docs/platform/observability.md`](./docs/platform/observability.md) |
| Add a new blueprint | [`CONTRIBUTING.md`](./CONTRIBUTING.md), [`docs/contribution-model.md`](./docs/contribution-model.md), and [`templates/workload-template`](./templates/workload-template) |

## Start here

1. Review the shared AKS baseline in [`platform/aks-avm`](./platform/aks-avm) and the platform-wide guidance in [`docs/platform`](./docs/platform).
2. Pick the shared operator path that matches your team: portal-first or `az` CLI-first.
3. Choose a workload under [`workloads`](./workloads) and read its `README.md`, `docs/architecture.md`, and deployment guide.
4. Use the workload Terraform or Bicep wrapper, then apply the workload-specific Kubernetes assets and validation steps.
5. When adding a new blueprint, start with [`CONTRIBUTING.md`](./CONTRIBUTING.md) and [`templates/workload-template`](./templates/workload-template).
6. Use [`blogs`](./blogs) when you are ready to turn the implementation into publishable guidance.
