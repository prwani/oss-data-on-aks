# Portal-first user journey

This repository supports teams that want to discover, deploy, and validate AKS data platforms from the Azure portal before moving to repeatable automation.

## Expected flow

1. Review the target workload folder and its architecture notes.
2. Use the shared AKS AVM guidance to understand the target cluster shape.
3. Validate networking, identity, storage, and monitoring choices in the portal.
4. Use the workload deployment guide to apply Helm charts, operators, or manifests.
5. Capture deviations and move the final configuration into Terraform or Bicep.

## What portal docs should cover

- prerequisites and Azure resource choices
- AKS cluster settings that matter for the workload
- node pools, storage classes, and networking options
- workload exposure model and security boundaries
- validation and day-2 operational checkpoints

