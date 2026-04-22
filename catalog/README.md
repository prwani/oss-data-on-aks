# Blueprint catalog

This catalog tracks the first wave of open-source data and analytics blueprints planned for this repository.

| Workload | Category | Portal path | `az` CLI path | Terraform | Bicep | Blog package |
| --- | --- | --- | --- | --- | --- | --- |
| OpenSearch | Search and analytics | Expanded | Expanded | Expanded | Expanded | Expanded |
| Redpanda | Streaming | Expanded | Expanded | Expanded | Expanded | Expanded |
| Apache Kafka | Streaming | Expanded | Expanded | Expanded | Expanded | Expanded |
| Trino | Query engines | Expanded | Expanded | Expanded | Expanded | Expanded |
| ClickHouse | OLAP databases | Expanded | Expanded | Expanded | Expanded | Expanded |
| Apache Airflow | Orchestration | Expanded | Expanded | Expanded | Expanded | Expanded |
| Apache Spark | Distributed processing | Expanded | Expanded | Expanded | Expanded | Expanded |
| Apache Superset | BI and semantic access | Expanded | Expanded | Expanded | Expanded | Expanded |

Expanded means the workload now includes concrete workload docs, AKS AVM-aligned Terraform and Bicep wrappers, pinned Kubernetes assets, and a workload-specific TechCommunity blog package.

## Expected blueprint shape

Each workload should grow toward the same minimum bar:

- shared AKS AVM baseline
- workload Terraform and Bicep entry points
- portal deployment walkthrough
- `az` CLI deployment walkthrough
- workload-specific operational guidance
- publishable blog artifacts
