# OpenSearch architecture notes

OpenSearch should be treated as a stateful platform workload, not as a generic stateless deployment.

## Initial design goals

- isolate stateful search workloads from general application pools
- use durable storage with clear capacity guidance
- keep the OpenSearch API private by default
- expose Dashboards deliberately and securely
- plan snapshots, observability, and upgrades early

## Likely AKS design choices

- dedicated node pools for cluster-manager and data roles as the blueprint matures
- Azure Disk CSI for primary data paths
- internal-only access for the API
- workload-specific Helm values and security hardening

