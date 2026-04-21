# `az` CLI-first user journey

This repository also supports teams that want a reproducible path from day one.

## Expected flow

1. Create or select the resource group.
2. Deploy the AKS baseline from either Terraform or Bicep.
3. Authenticate with `az` and connect with `kubectl`.
4. Apply workload-specific prerequisites.
5. Install and validate the target data platform.

## What CLI docs should cover

- minimal prerequisite toolchain
- Azure login and subscription selection
- cluster deployment commands
- cluster credentials and namespace preparation
- workload install, validation, and cleanup steps

