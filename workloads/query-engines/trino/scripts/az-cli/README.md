# Trino CLI command notes

The repeatable install and validation flow lives in `../../docs/az-cli-deployment.md`.

This folder intentionally does not ship a single wrapper script because AKS cluster names, internal DNS choices, and future catalog bindings vary by environment. Keeping the commands inline in the deployment guide makes review and operator customization easier while still leaving the blueprint fully runnable.
