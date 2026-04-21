# Shared security guidance

Security guidance should be inherited by every workload blueprint.

## Baseline themes

- private cluster or private access where practical
- managed identities over static secrets
- workload isolation with dedicated namespaces and, where needed, node pools
- ingress and API exposure based on least privilege
- secret storage externalization where possible

## Workload-specific follow-up

Each workload folder should refine:

- admin bootstrap flow
- certificate strategy
- internal versus external endpoints
- backup credential handling
- operator or chart hardening settings

