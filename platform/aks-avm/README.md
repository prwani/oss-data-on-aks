# AKS AVM baseline

All blueprints in this repository should use AKS Azure Verified Modules as the base cluster deployment mechanism.

## References

- Terraform AVM module: `Azure/avm-res-containerservice-managedcluster/azurerm`
- Bicep AVM module: `br/public:avm/res/container-service/managed-cluster:<version>`

## Intended usage

- use the shared files here for cluster-level infrastructure
- extend workload folders with their own storage, operator, ingress, and policy needs
- pin tested AVM versions before productionizing a workload

## Notes for the initial scaffold

The Terraform and Bicep files in this folder are intentionally starter files. They show the reference points and the minimum contract that workload folders should inherit, while leaving room to pin exact AVM versions and full parameter sets as each blueprint matures.

