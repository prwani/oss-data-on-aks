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
├── docs/                   # Shared platform and operator guidance
├── platform/               # Shared AKS AVM baseline for Terraform and Bicep
├── templates/              # Reusable starter files for future workloads
└── workloads/              # Workload blueprints grouped by platform category
```

## Start here

1. Review the shared AKS baseline in [`platform/aks-avm`](./platform/aks-avm).
2. Pick a workload under [`workloads`](./workloads).
3. Follow either the portal or `az` CLI guidance in that workload.
4. Extend the workload-specific Terraform and Bicep entry points.
5. Use [`blogs`](./blogs) when you are ready to turn the implementation into publishable guidance.
