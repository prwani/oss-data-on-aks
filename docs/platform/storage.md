# Shared storage guidance

Most target workloads in this repository are stateful and should not be treated like standard stateless microservices.

## Baseline themes

- prefer Azure Disk CSI for primary stateful data paths
- choose SKU and sizing per workload latency and throughput profile
- separate ephemeral scratch from durable platform data
- document backup, restore, and retention expectations up front
- keep storage classes and PVC expectations visible in workload docs

