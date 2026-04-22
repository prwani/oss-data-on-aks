# `<workload>` `az` CLI deployment path

Replace the placeholders in this file and keep it runnable. The goal is to give operators one source-controlled CLI walkthrough that matches the checked-in Terraform, Bicep, Helm, and manifest assets.

## Prerequisites

- Azure CLI
- `kubectl`
- Helm 3.x or the workload-specific CLI/tooling required by the install
- Terraform 1.11+ if the workload keeps the Terraform path
- an Azure subscription with quota for the planned node pools

## Environment variables

```bash
export LOCATION=eastus
export RESOURCE_GROUP=rg-<workload>-aks-dev
export CLUSTER_NAME=aks-<workload>-dev
export NAMESPACE=<workload>
export CHART_VERSION=<pin-me>
```

Add any workload-specific values such as admin usernames, secret names, or pool names next to this block.

## Option A: Bicep wrapper

```bash
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file workloads/<category>/<workload>/infra/bicep/main.bicep \
  --parameters clusterName="$CLUSTER_NAME" location="$LOCATION"
```

Describe the expected cluster shape here, such as the dedicated user pool name and why the workload needs it.

## Option B: Terraform wrapper

```bash
cd workloads/<category>/<workload>/infra/terraform
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform plan
terraform apply
```

Call out any variables that operators are expected to edit before `terraform apply`.

## Connect to AKS

```bash
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME"
```

## Prepare the namespace, storage class, and secrets

Keep the prerequisite assets source controlled where possible:

```bash
kubectl apply -f workloads/<category>/<workload>/kubernetes/manifests/namespace.yaml
```

Add any storage-class manifest, secret-generation commands, or operator prerequisites here. Do not check generated secrets into the repo; show operators how to create them safely at deploy time.

## Install the workload

Point directly to the checked-in values file or manifests:

```bash
helm repo add <chart-repo-name> <chart-repo-url>
helm repo update

helm upgrade --install <release-name> <chart-repo-name>/<chart-name> \
  --version "$CHART_VERSION" \
  --namespace "$NAMESPACE" \
  --values workloads/<category>/<workload>/kubernetes/helm/workload-values.yaml
```

If the workload is installed through operators or raw manifests, replace the Helm example with the real commands.

## Validate the deployment

Keep the validation section concrete. Typical repo patterns include:

```bash
kubectl get pods,svc -n "$NAMESPACE"
kubectl describe <resource-kind> <resource-name> -n "$NAMESPACE"
```

Add workload-native smoke tests here: SQL queries, API checks, topic creation, dashboard access, or operator status commands.

## Implementation notes

Close the guide with the details operators must not guess, for example:

- expected release name and namespace
- internal-only access model
- required secrets or certificates
- dedicated node-pool labels and taints
- where to find day-2 commands in `docs/operations.md`
