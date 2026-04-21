# Shared platform architecture

The shared platform layer exists to keep workload blueprints consistent.

## Baseline assumptions

- AKS is provisioned through Azure Verified Modules.
- networking, node pools, and identity are managed centrally first
- workload folders extend the baseline instead of redefining it
- stateful platforms get explicit storage, security, and observability guidance

## Recommended shared building blocks

- resource group and landing-zone alignment
- virtual network and subnet placement
- managed identity and role assignment model
- Azure Monitor and Log Analytics integration
- workload ingress and private access patterns
- storage classes for stateful services

