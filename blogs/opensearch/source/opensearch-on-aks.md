# Deploying OpenSearch on AKS with an AKS AVM baseline

**Publication target:** Microsoft TechCommunity > Azure > Linux and Open Source Blog

## Summary

This post introduces an Azure-first pattern for deploying OpenSearch on AKS. It uses AKS Azure Verified Modules as the cluster baseline, keeps Terraform and Bicep entry points side by side, and gives both portal-oriented and CLI-oriented teams a starting path.

## Why OpenSearch on AKS

OpenSearch is a strong fit when teams want a Kubernetes-native search and analytics platform but still need Azure-native guardrails for identity, networking, storage, and operations. The AKS challenge is not just getting pods to run. It is choosing the right node pools, storage classes, exposure model, and day-2 guardrails for a stateful search platform.

## What this repo contributes

- a shared AKS AVM baseline for cluster creation
- workload-specific Terraform and Bicep entry points
- portal and `az` CLI guidance
- a place to capture production-minded operational guidance

## Suggested article flow

1. Explain the shared AKS AVM baseline.
2. Show where the OpenSearch workload assets live in this repo.
3. Walk through the portal-first operator path.
4. Walk through the CLI-first path.
5. Install OpenSearch and validate cluster health.
6. Close with the transition to production-minded design choices.

## Key talking points

- use dedicated storage and explicit capacity planning
- prefer private access to the OpenSearch API
- separate cluster-manager and data concerns as the workload matures
- treat observability and snapshots as first-class requirements

