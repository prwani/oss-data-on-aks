# OpenSearch on AKS

This blueprint is the first expanded workload in the repository and the reference pattern for stateful search and analytics platforms on AKS.

## What this blueprint is optimizing for

- **AKS AVM baseline** for the cluster foundation
- **Terraform and Bicep** entry points side by side
- **Portal-first** and **`az` CLI-first** operator journeys
- **Stateful workload guidance** for storage, node pools, private access, and operations
- **TechCommunity-ready blog content** aligned to the implementation assets in [`blogs/opensearch`](../../../blogs/opensearch)

## Why this is not a typical AKS microservice

Most AKS application workloads are deployed as stateless `Deployment`s and depend on an external database for durability. OpenSearch is different:

- manager and data tiers run as **StatefulSets**, not generic stateless deployments
- each **manager pod needs its own disk** for cluster metadata durability
- each **data pod needs its own disk** for shard storage, relocation, and recovery
- `kubectl get pvc` is a first-class deployment check, not an optional extra, because a pod cannot start until its **PersistentVolumeClaim (PVC)** is `Bound`

Those storage and topology requirements are why this blueprint emphasizes dedicated node pools, per-pod Azure Disks, private API exposure, and snapshot planning from the start.

## Recommended starting pattern

| Layer | Recommendation | Why |
| --- | --- | --- |
| AKS baseline | Shared AVM wrapper | Keeps cluster creation consistent across workloads |
| Cluster-manager tier | Dedicated Helm release and dedicated node pool | Protects elections and cluster metadata |
| Data tier | Dedicated Helm release and dedicated node pool | Isolates shard-heavy storage and indexing traffic |
| OpenSearch API | `ClusterIP` only | Limits attack surface |
| Dashboards | Internal Azure load balancer | Gives operators access without exposing the API publicly |
| Persistent storage | `managed-csi-premium` | Sensible default for durable SSD-backed volumes |
| Snapshots | Azure Blob Storage with AKS Workload Identity | External recovery point beyond PVCs without storage account keys |

The checked-in Azure wrappers now make the snapshot path explicitly keyless: they enable AKS workload identity, create a user-assigned managed identity plus federated credentials for the manager and data service accounts, and disable shared-key access on the starter storage account.

## Architecture visuals

The first two figures below are official OpenSearch diagrams that explain the logical cluster model and shard/replica placement. The remaining figures map those ideas onto this repository's standard and secure AKS deployment patterns.

![Official OpenSearch cluster architecture](../../../blogs/opensearch/assets/opensearch-cluster.png)

*Source: [OpenSearch documentation cluster architecture diagram](https://docs.opensearch.org/latest/images/cluster.png), OpenSearch Contributors, Apache License 2.0.*

![Official OpenSearch shard and replica architecture](../../../blogs/opensearch/assets/opensearch-cluster-replicas.png)

*Source: [OpenSearch documentation shard and replica diagram](https://docs.opensearch.org/latest/images/intro/cluster-replicas.png), OpenSearch Contributors, Apache License 2.0.*

![Combined OpenSearch-on-AKS architecture](../../../blogs/opensearch/assets/opensearch-on-aks-combined-architecture.svg)

*Custom AKS mapping for this repository. It combines OpenSearch cluster roles, shard/replica behavior, dedicated AKS node pools, StatefulSets, and per-pod PVC-backed Azure Disks.*

![Secure OpenSearch-on-AKS architecture](../../../blogs/opensearch/assets/opensearch-on-aks-secure-architecture.svg)

*Secure deployment mapping using Microsoft Azure Architecture Icons. It highlights the private AKS API, deployment script subnet, internal Dashboards load balancer, workload identity to Blob snapshots, and encrypted persistent disks.*

## Blueprint contents

- `docs/architecture.md`
- `docs/portal-deployment.md`
- `docs/az-cli-deployment.md`
- `docs/operations.md`
- `infra/terraform/main.tf`
- `infra/terraform/terraform.tfvars.example`
- `infra/bicep/main.bicep`
- `infra/bicep/main.bicepparam`
- `infra/portal/azuredeploy.json`
- `infra/portal/azuredeploy-full.json`
- `infra/portal/azuredeploy-secure.json`
- `infra/portal/full-deploy.bicep`
- `infra/portal/secure-full-deploy.bicep`
- `scripts/az-cli/deploy.sh`
- `kubernetes/helm`
- `kubernetes/manifests`

## Deployment shortcuts

Use the portal button when you want Azure to prompt for values and run the full deployment, including AKS, node pools, snapshot storage, workload identity, Kubernetes secrets, Helm releases, readiness checks, and snapshot repository verification:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fprwani%2Foss-data-on-aks%2Fmain%2Fworkloads%2Fsearch-analytics%2Fopensearch%2Finfra%2Fportal%2Fazuredeploy-full.json)

The full portal template asks for an OpenSearch admin password and passes it to an Azure deployment script as a secure parameter. If you only want the Azure baseline and prefer to run the Kubernetes and Helm steps yourself, use `infra/portal/azuredeploy.json`.

Use the secure portal button when you also want a private AKS control plane. It creates a VNet, private AKS API server, and VNet-integrated deployment script subnet so the portal-run script can still reach the private API:

[![Deploy to Azure (secure)](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fprwani%2Foss-data-on-aks%2Fmain%2Fworkloads%2Fsearch-analytics%2Fopensearch%2Finfra%2Fportal%2Fazuredeploy-secure.json)

Use the one-command script when you want the full end-to-end flow, including Kubernetes namespace bootstrap, secrets, Helm releases, readiness checks, and snapshot repository verification:

```bash
workloads/search-analytics/opensearch/scripts/az-cli/deploy.sh
```

## Standard release names

The workload guidance assumes the following Helm release names:

1. `opensearch-manager`
2. `opensearch-data`
3. `opensearch-dashboards`

Using stable release names keeps service discovery, example manifests, and documentation aligned.

## Scope of the current implementation

This blueprint now includes:

- a documented target architecture
- example Azure deployment wrappers for the AKS baseline and a managed-identity-first snapshot storage path
- Helm values for manager nodes, data nodes, and Dashboards
- namespace and secret examples plus workload-identity-aware Helm settings
- a two-part blog package for external publication

It does **not** yet claim to automate every production hardening task end to end. Snapshot repository registration is still an operator step, and certificate replacement plus private endpoint integration should still be validated for the target environment.
