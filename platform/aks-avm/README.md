# AKS AVM baseline

All blueprints in this repository should use AKS Azure Verified Modules as the base cluster deployment mechanism.

## References

- Terraform AVM module: `Azure/avm-res-containerservice-managedcluster/azurerm`
- Bicep AVM module: `br/public:avm/res/container-service/managed-cluster:<version>`

## Intended usage

- use the shared files here for cluster-level infrastructure
- extend workload folders with their own storage, operator, ingress, and policy needs
- keep the shared wrappers pinned to tested AVM versions instead of floating or placeholder references

## Current baseline shape

- Terraform wrapper pins `Azure/avm-res-containerservice-managedcluster/azurerm` `0.5.3`
- Bicep wrapper pins `br/public:avm/res/container-service/managed-cluster:0.13.0`
- Those Terraform and Bicep module versions come from separate AVM release streams and are pinned independently, so the numbers are not expected to match semantically.
- both wrappers accept a system pool definition plus any workload-specific user pools
- both wrappers default to a small `systempool` and let workload folders add dedicated pools such as `osmgr` and `osdata`
- both wrappers now expose shared cluster identity outputs such as the AKS resource ID, kubelet identity details, and OIDC issuer metadata when workloads enable those features through the wrapper
