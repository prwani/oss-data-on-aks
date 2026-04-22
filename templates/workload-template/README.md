# Workload template

Use this template when onboarding the next blueprint. It mirrors the file set the expanded workloads now keep checked in, while staying generic enough to adapt to a new chart, operator, or data platform.

## Starter layout

```text
templates/workload-template
├── README.md
├── docs/
│   ├── architecture.md
│   ├── az-cli-deployment.md
│   ├── operations.md
│   └── portal-deployment.md
├── infra/
│   ├── bicep/
│   │   ├── main.bicep
│   │   └── main.bicepparam
│   └── terraform/
│       ├── main.tf
│       ├── outputs.tf
│       ├── terraform.tfvars.example
│       └── variables.tf
├── kubernetes/
│   ├── README.md
│   ├── helm/
│   │   ├── README.md
│   │   └── workload-values.yaml
│   └── manifests/
│       ├── README.md
│       └── namespace.yaml
└── scripts/
    ├── README.md
    └── az-cli/
        └── README.md
```

## Repo conventions to preserve

- extend the shared AKS baseline in [`../../platform/aks-avm`](../../platform/aks-avm) instead of redefining cluster creation
- keep Terraform and Bicep wrappers aligned
- keep both operator journeys: portal-first and `az` CLI-first
- ship `docs/architecture.md` and `docs/operations.md`, not only install steps
- keep service exposure internal by default unless the workload docs justify an exception
- keep secrets out of source control; document how to generate or inject them at deploy time

## First edits after copying the template

1. rename the target folder under `workloads/<category>/<workload>`
2. replace placeholder workload, namespace, and node-pool names
3. pin the real chart or operator version in the workload docs and `kubernetes/helm`
4. update the Terraform and Bicep wrappers to match the intended pool sizing and labels
5. replace the architecture and operations prompts with workload-specific guidance
6. add any extra manifests needed for storage classes, CRDs, or runtime bootstrap

## Files you are expected to personalize

| File | What to replace |
| --- | --- |
| `docs/architecture.md` | the AKS topology, sizing logic, service exposure, and state model |
| `docs/portal-deployment.md` | portal-specific cluster and install steps |
| `docs/az-cli-deployment.md` | runnable Bicep/Terraform, Helm, and validation commands |
| `docs/operations.md` | day-2 checks, upgrade rules, backup posture, and runbooks |
| `infra/terraform/*` and `infra/bicep/*` | real pool names, counts, tags, and outputs |
| `kubernetes/helm/workload-values.yaml` | chart-specific values, selectors, tolerations, and storage settings |
| `kubernetes/manifests/*` | namespace labels, storage classes, CRDs, or helper manifests |

For the full onboarding workflow, see [`../../CONTRIBUTING.md`](../../CONTRIBUTING.md).
