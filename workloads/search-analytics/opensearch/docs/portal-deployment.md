# OpenSearch portal deployment path

Use this guide for a portal-oriented walkthrough.

## Suggested flow

1. Review the shared AKS AVM baseline and choose the target region.
2. Create or select the resource group and networking foundation.
3. Validate node pool sizing and storage expectations for OpenSearch.
4. Deploy the AKS cluster using the shared baseline as the reference contract.
5. Connect to the cluster and install OpenSearch from the workload assets.
6. Validate cluster health, Dashboards access, and storage provisioning.

## Extra checks for OpenSearch

- confirm storage SKU and PVC sizing
- confirm private versus internal-only exposure model
- confirm the monitoring and snapshot strategy before production use

