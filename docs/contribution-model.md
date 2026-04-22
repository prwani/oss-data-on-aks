# Contribution model

This repository keeps **shared guidance** and **workload-specific blueprints** separate on purpose. That separation is what lets the expanded workloads stay consistent without turning every folder into a copy of every other folder.

Use [`../CONTRIBUTING.md`](../CONTRIBUTING.md) for the step-by-step onboarding flow. This document explains the information architecture that new blueprints should follow.

## Shared-first layout

| Path | Purpose | Update it when... |
| --- | --- | --- |
| `docs/platform/*` | shared architecture, security, storage, and observability conventions | a repo-wide baseline changes |
| `docs/user-journeys/*` | shared navigation for portal-first and `az` CLI-first operators | more than one workload benefits from the same guidance |
| `platform/aks-avm/*` | shared Terraform and Bicep AKS baseline | the cluster-level wrapper changes |
| `templates/workload-template` | starter shape for the next workload blueprint | the common workload file set changes |

## Workload blueprint contract

Every workload folder should be a self-contained blueprint that includes:

1. a `README.md` that explains the target platform and repo-specific scope
2. architecture, deployment, and operations docs under `docs/`
3. Terraform and Bicep wrappers under `infra/`
4. Kubernetes values and manifests under `kubernetes/`
5. optional helper notes or scripts under `scripts/`

## Shared rules that current workloads follow

- keep the shared AKS baseline in `platform/aks-avm`
- keep Terraform and Bicep entry points side by side
- keep portal-first and `az` CLI-first docs
- keep secrets out of Git
- keep service exposure internal by default unless the workload docs justify something else
- keep architecture and day-2 operations notes in the workload folder

## Workflow for a new blueprint

1. copy [`templates/workload-template`](../templates/workload-template) into the correct `workloads/<category>/<workload>` folder
2. replace placeholder names, namespace, and node-pool details
3. fill in the workload-specific architecture, deployment, and operations guidance
4. pin the chart/operator versions and align the Kubernetes assets with the docs
5. validate the Terraform, Bicep, and documentation paths before treating the blueprint as complete

## When to change shared docs instead of a workload

Prefer a shared-doc update when the change affects multiple blueprints, such as:

- a new identity or storage convention
- a repeated portal or CLI step that should be explained once
- a repo-wide template or contributor workflow change
