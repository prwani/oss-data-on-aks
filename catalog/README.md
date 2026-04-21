# Blueprint catalog

This catalog tracks the first wave of open-source data and analytics blueprints planned for this repository.

| Workload | Category | Portal path | `az` CLI path | Terraform | Bicep | Blog package |
| --- | --- | --- | --- | --- | --- | --- |
| OpenSearch | Search and analytics | Planned | Planned | Scaffolded | Scaffolded | Seeded |
| Redpanda | Streaming | Planned | Planned | Scaffolded | Scaffolded | Template-driven |
| Apache Kafka | Streaming | Planned | Planned | Scaffolded | Scaffolded | Template-driven |
| Trino | Query engines | Planned | Planned | Scaffolded | Scaffolded | Template-driven |
| ClickHouse | OLAP databases | Planned | Planned | Scaffolded | Scaffolded | Template-driven |
| Apache Airflow | Orchestration | Planned | Planned | Scaffolded | Scaffolded | Template-driven |
| Apache Spark | Distributed processing | Planned | Planned | Scaffolded | Scaffolded | Template-driven |
| Apache Superset | BI and semantic access | Planned | Planned | Scaffolded | Scaffolded | Template-driven |

## Expected blueprint shape

Each workload should grow toward the same minimum bar:

- shared AKS AVM baseline
- workload Terraform and Bicep entry points
- portal deployment walkthrough
- `az` CLI deployment walkthrough
- workload-specific operational guidance
- publishable blog artifacts

