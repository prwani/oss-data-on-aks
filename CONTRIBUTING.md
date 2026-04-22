# Contributing

Use this repository to produce complete AKS blueprints, not one-off Helm values or partial notes. A new workload should be understandable to an operator who only has the checked-in repo.

## Before you add a workload

Review the shared guidance first:

- [`docs/platform/architecture.md`](./docs/platform/architecture.md)
- [`docs/platform/security.md`](./docs/platform/security.md)
- [`docs/platform/storage.md`](./docs/platform/storage.md)
- [`docs/platform/observability.md`](./docs/platform/observability.md)
- [`docs/user-journeys/portal.md`](./docs/user-journeys/portal.md)
- [`docs/user-journeys/az-cli.md`](./docs/user-journeys/az-cli.md)

Then start from [`templates/workload-template`](./templates/workload-template).

## Adding a new workload

### 1. Copy the template into the right category

Create the workload under `workloads/<category>/<workload>` and keep the category structure consistent with the existing repo layout.

### 2. Replace the placeholders

Update at least these shared identifiers:

- workload name
- Kubernetes namespace
- dedicated node-pool name
- resource-group and cluster naming pattern
- chart or operator version pins

Keep those names aligned across `README.md`, `docs/`, Terraform, Bicep, Helm values, and manifests.

### 3. Fill the workload docs

Every new workload should include:

- `README.md` for scope, topology, and contents
- `docs/architecture.md` for the AKS-specific design
- `docs/portal-deployment.md` for the portal-first path
- `docs/az-cli-deployment.md` for the automation-first path
- `docs/operations.md` for validation, upgrades, and runbooks

The workload docs should explain why the platform is not just a generic AKS microservice, what stays internal by default, and what storage, identity, or bootstrap steps the operator must understand.

### 4. Extend the shared AKS baseline, do not replace it

Workload wrappers should call into [`platform/aks-avm`](./platform/aks-avm) and then add only the workload-specific cluster shape:

- dedicated user pools
- tags
- naming
- any required cluster options that differ from the default baseline

Keep Terraform and Bicep aligned. If one wrapper adds a dedicated pool, the other should describe the same starter intent.

### 5. Add workload-local Kubernetes assets

At minimum, keep:

- `kubernetes/helm/README.md`
- one checked-in values file
- `kubernetes/manifests/README.md`
- `kubernetes/manifests/namespace.yaml`

Add storage-class manifests, CRDs, or helper manifests only when the workload needs them. Keep runtime-generated secrets out of Git.

### 6. Add helper notes only when they stay honest

Use `scripts/az-cli` for small wrappers or notes that automate the documented flow. Do not hide important install choices inside opaque scripts.

### 7. Follow the repo conventions

| Convention | Expectation |
| --- | --- |
| AKS baseline | shared AVM wrappers |
| IaC | Terraform and Bicep side by side |
| Access model | internal-only by default unless explicitly justified |
| Secrets | generated or injected at deploy time, never committed |
| Azure integrations | managed identity or workload identity over shared keys |
| Day-2 guidance | keep operations notes in the workload folder |

### 8. Validate before calling it done

Use the most relevant checks available to you. For most new blueprints, that means:

- `terraform fmt -check` on the workload Terraform wrapper
- reviewing the `.bicepparam` file against the Bicep parameters
- checking that Markdown links resolve and point to real repo paths
- making sure the deployment guides reference the checked-in manifests and values files that actually exist

### 9. Update surrounding shared assets when needed

If the new blueprint introduces a repo-wide convention, update the shared docs or template in the same change. If the workload is ready for external storytelling, add or expand the matching blog package when that work is in scope.

## Pull-request checklist

Before opening a PR, confirm:

- the workload folder is complete enough to follow without guessing
- Terraform and Bicep wrappers describe the same starter cluster shape
- the docs explain secrets, identity, storage, and validation clearly
- internal-only defaults stay intact unless the architecture notes justify something else
- shared docs were updated if the repo-wide baseline changed
