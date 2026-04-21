# Shared platform assets

This directory holds the reusable AKS platform baseline that workload blueprints should build on.

## Current contents

- `aks-avm/terraform`: Terraform starter files that reference the AKS AVM module
- `aks-avm/bicep`: Bicep starter files that reference the AKS AVM managed cluster module

Workload folders should call into these assets instead of duplicating the AKS baseline.

