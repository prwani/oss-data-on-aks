# OpenSearch CLI scripts

This folder contains helper scripts that stay close to the OpenSearch blueprint.

## One-command deployment

Run the full deployment flow with:

```bash
workloads/search-analytics/opensearch/scripts/az-cli/deploy.sh
```

The script prompts for:

- deployment engine: `bicep` or `terraform`
- Azure region
- resource group
- AKS cluster name
- snapshot storage account name
- OpenSearch admin password

It then runs the Azure deployment, connects to AKS, creates the namespace and secrets, installs the manager, data, and Dashboards Helm releases, waits for readiness, registers the Azure Blob snapshot repository, and prints the Dashboards access details.

You can also pre-seed values with environment variables for repeatable runs:

```bash
DEPLOY_ENGINE=terraform \
LOCATION=swedencentral \
RESOURCE_GROUP=rg-opensearch-aks-dev \
CLUSTER_NAME=aks-opensearch-dev \
SNAPSHOT_STORAGE_ACCOUNT=opssnapdev001 \
ADMIN_PASSWORD='<strong-admin-password>' \
workloads/search-analytics/opensearch/scripts/az-cli/deploy.sh
```
