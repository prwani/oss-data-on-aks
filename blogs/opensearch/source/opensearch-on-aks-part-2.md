# OpenSearch on AKS, part 2: production-minded design and day-2 guidance

**Publication target:** Microsoft TechCommunity > Azure > Linux and Open Source Blog

## Summary

This follow-up post shifts from initial deployment to long-term operating posture. It focuses on stateful workload design choices for OpenSearch on AKS: dedicated node pools, storage planning, internal exposure, resilience, and recovery.

## Focus areas

1. dedicated node pools for data-heavy search workloads
2. Azure Disk CSI choices and storage sizing
3. private access patterns for the OpenSearch API
4. dashboards exposure and operator access
5. snapshots, recovery, and backup expectations
6. monitoring and alerting signals that matter in production

## Relationship to part 1

Part 1 should answer, "How do I get OpenSearch running on AKS with a clean Azure baseline?"  
Part 2 should answer, "What changes when I want OpenSearch to behave like a durable platform instead of a short-lived demo?"

## Editorial direction

- keep comparisons with stateless microservices explicit
- show why storage and memory headroom matter
- connect each best practice to a concrete AKS decision
- point readers back to the workload folder for the evolving blueprint artifacts

