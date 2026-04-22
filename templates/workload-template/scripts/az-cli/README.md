# `<workload>` CLI helper area

Use this folder for optional helpers that automate the documented CLI path.

## Good uses for this folder

- wrappers around the Terraform or Bicep deployment commands
- idempotent secret-generation helpers that still keep secrets out of Git
- rollout diagnostics or validation helpers
- cleanup scripts for repeatable test environments

Keep the authoritative steps in `../../docs/az-cli-deployment.md` and `../../docs/operations.md`.
