# Redpanda `az` CLI scripts

This folder is reserved for helper scripts that should stay close to the Redpanda blueprint.

Prefer scripts here for:

- resource group, quota, and AKS credential validation
- cert-manager bootstrap on AKS
- Helm install and rollout-wait helpers
- PVC, certificate, and admin API validation
- optional day-2 helpers for enabling SASL or tiered storage with managed identity

Avoid checking in scripts that mint sample secrets or hardcode external listener endpoints. Those decisions should stay environment specific.
