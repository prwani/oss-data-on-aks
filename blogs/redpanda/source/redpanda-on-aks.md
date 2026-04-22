# Running Redpanda on AKS with a dedicated broker pool and internal-only listeners

**Publication target:** Microsoft TechCommunity > Azure > Linux and Open Source Blog

## Summary

Redpanda is easy to demo with Helm, but a reusable AKS pattern needs more than `helm install`. In this post, I walk through a starter blueprint that uses AKS Azure Verified Modules (AVM) for the cluster baseline, a dedicated `rpbroker` user pool, Premium SSD-backed PVCs, cert-manager-backed TLS, and internal-only listeners by default.

The goal is not to pretend every day-2 decision is solved. The goal is to give platform teams a clean Azure-first starting point that already reflects the parts of Redpanda that make it very different from a stateless microservice.

## Why standardize Redpanda on AKS

Redpanda is attractive on AKS when teams want:

- Kafka API compatibility without standing up ZooKeeper
- Kubernetes-native deployment and operations
- Azure-managed infrastructure for nodes, disks, and networking
- a clear path from lab to production-minded platform design

The challenge is that Redpanda is not just another app behind a service. It is a stateful streaming system with per-broker storage, broker-local recovery behavior, listener design constraints, and strict CPU requirements. A real AKS blueprint has to account for all of that up front.

## What makes Redpanda on AKS different from a stateless app

This is the point I want readers to notice early: **Redpanda on AKS is not a normal stateless microservice deployment**.

Typical AKS microservices often look like this:

- a `Deployment`
- replicas that can restart almost anywhere
- little or no persistent per-pod storage
- durable state stored in another service

Redpanda is different:

- brokers run as a **StatefulSet**
- each broker owns its own **PersistentVolumeClaim (PVC)**
- a missing or unbound PVC blocks broker startup
- listener design matters because clients need stable broker addresses
- Redpanda requires **x86_64 CPUs with SSE4.2 support**

That is why Redpanda validation on AKS needs to include `kubectl get pvc`, broker placement, and listener posture checks. `kubectl get pods` alone is not enough.

## What the repo now provides

The Redpanda workload in the repo is organized around five practical building blocks:

1. a shared AKS baseline under `platform/aks-avm`
2. workload wrappers for Terraform and Bicep under `workloads/streaming/redpanda/infra`
3. deployment guidance for portal-first and CLI-first operators under `workloads/streaming/redpanda/docs`
4. Helm values and Kubernetes manifests under `workloads/streaming/redpanda/kubernetes`
5. publish-ready blog assets under `blogs/redpanda`

That split is deliberate. It keeps AKS platform choices reusable while still letting the Redpanda workload carry its own install and operations guidance.

## Checked-in version contract

These are the repo-backed versions this walkthrough currently matches.

| Component | Checked-in version | Evidence in repo |
| --- | --- | --- |
| cert-manager prerequisite | `v1.17.2` | `workloads/streaming/redpanda/kubernetes/helm/README.md` |
| Helm chart | `redpanda/redpanda` `26.1.1` | `workloads/streaming/redpanda/kubernetes/helm/README.md` |
| Runtime image tag | `v26.1.1` | `workloads/streaming/redpanda/kubernetes/helm/redpanda-values.yaml` |


## The target architecture

For the starter Redpanda blueprint, I am using this pattern:

| Layer | Recommendation | Why |
| --- | --- | --- |
| AKS baseline | Shared AVM wrapper | Keeps cluster creation consistent across workloads |
| System pool | `systempool` for cert-manager and add-ons | Keeps broker nodes focused on streaming traffic |
| Broker pool | Dedicated `rpbroker` pool with 3 nodes | Gives the 3-broker StatefulSet one dedicated node per broker |
| Helm release | `redpanda/redpanda` chart `26.1.1` | Pins the runtime shape and chart behavior |
| TLS | cert-manager-backed and enabled by default | Encrypts internal traffic without checking secrets into the repo |
| Auth | SASL disabled in starter values | Keeps the repo secret-free; enable later with external secret delivery |
| Storage | `managed-csi-premium`, 256 GiB per broker | Durable Premium SSD-backed storage with expansion support |
| Exposure | Internal-only by default | Avoids premature advertised-listener complexity |

## Prerequisites

Before you start, make sure you have:

- an Azure subscription with AKS and managed disk quota
- Azure CLI installed and logged in
- `kubectl` installed
- Helm 3.10 or later
- Terraform 1.11+ if you want the Terraform path
- cert-manager `v1.17.2` available for the cluster

For the broker pool, the blueprint uses `Standard_D8ds_v5` as the concrete starter size. If you choose another SKU, keep the same practical rules:

- stay on **x86_64**
- keep **SSE4.2** support
- keep at least **3 broker nodes**

## Step 1: Deploy or align the AKS baseline

This repo keeps both IaC options visible because teams standardize differently.

### Bicep path

```bash
export LOCATION=eastus
export RESOURCE_GROUP=rg-redpanda-aks-dev
export CLUSTER_NAME=aks-redpanda-dev
export SYSTEM_POOL_VM_SIZE=Standard_D4ds_v5
export BROKER_POOL_VM_SIZE=Standard_D8ds_v5

az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file workloads/streaming/redpanda/infra/bicep/main.bicep \
  --parameters \
      clusterName="$CLUSTER_NAME" \
      location="$LOCATION" \
      systemPoolVmSize="$SYSTEM_POOL_VM_SIZE" \
      brokerPoolVmSize="$BROKER_POOL_VM_SIZE" \
      brokerPoolCount=3
```

### Terraform path

```bash
cd workloads/streaming/redpanda/infra/terraform
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform plan
terraform apply
```

The checked-in wrappers provision `systempool` and `rpbroker`. The `rpbroker` pool starts with three nodes and the taint `dedicated=redpanda-broker:NoSchedule`, which matches the node selector and toleration in the Helm values.

## Step 2: Connect to AKS and install cert-manager

Once the cluster is ready, connect to it:

```bash
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME"
```

Then install cert-manager, because the chart keeps TLS enabled:

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.17.2/cert-manager.yaml

kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-webhook -n cert-manager
```

## Step 3: Create the namespace and storage class

```bash
kubectl apply -f workloads/streaming/redpanda/kubernetes/manifests/managed-csi-premium-storageclass.yaml
kubectl apply -f workloads/streaming/redpanda/kubernetes/manifests/namespace.yaml
```

The namespace manifest is an AKS-specific callout worth noticing. The checked-in Redpanda values keep `tuning.tune_aio_events: true`, which creates a privileged tuning container. That is why the namespace uses the `privileged` Pod Security profile. This is another way Redpanda differs from a basic stateless app.

## Step 4: Install Redpanda 26.1.1

```bash
helm repo add redpanda https://charts.redpanda.com
helm repo update

helm upgrade --install redpanda redpanda/redpanda \
  --version 26.1.1 \
  --namespace redpanda \
  --values workloads/streaming/redpanda/kubernetes/helm/redpanda-values.yaml

kubectl rollout status statefulset/redpanda -n redpanda --timeout=15m
```

The checked-in values do four important things for AKS:

1. pin the Redpanda image to `v26.1.1`
2. keep the cluster at **3 brokers**
3. place brokers only on the dedicated `rpbroker` pool
4. keep **external listeners off** so the default install stays internal only

## Step 5: Validate what matters

At minimum, validate pod placement, PVC binding, certificate readiness, and service exposure:

```bash
kubectl get pods -n redpanda -o wide
kubectl get pvc -n redpanda
kubectl get certificates -n redpanda
kubectl get svc -n redpanda
```

For this workload, the PVC check is not just nice to have. Each broker depends on its own Azure Disk-backed PVC, so every claim needs to be `Bound` before you trust the rollout.

For an internal-only readiness check, use the admin API over port-forward:

```bash
kubectl port-forward svc/redpanda 9644:9644 -n redpanda
curl -sk https://127.0.0.1:9644/v1/status/ready
curl -sk https://127.0.0.1:9644/v1/cluster/health_overview
```

## AKS-specific design choices that matter

### Dedicated broker pool

The blueprint uses `systempool` for add-ons and a dedicated `rpbroker` user pool for brokers. That gives Redpanda predictable CPU and scheduling behavior and avoids noisy-neighbor placement with general application workloads.

### Premium SSD-backed PVCs

The storage class is explicit and the broker disks are persistent. That is very different from a stateless app that can live happily on ephemeral root storage. On AKS, Redpanda durability starts with the PVC and Azure Disk attachment path.

### Internal-only default

This repo keeps `external.enabled: false` on purpose. External Redpanda access is not just a service toggle; it is an advertised-listener design problem. Each broker needs a stable address. Keeping the default install internal-only is a safer starting point for platform teams.

### TLS on, SASL later

The starter values keep TLS enabled and SASL disabled. That gives you encrypted traffic without checking secrets into source control. Before production or off-cluster access, enable SASL through an external secret workflow and align certificate handling with your PKI policy.

### Tiered storage boundary

The checked-in values leave tiered storage off. When you later enable Azure Blob-backed tiered storage, keep the Azure guidance intact: use **managed identity-based access**, not storage account shared keys.

## Why I like this starting pattern

It gives teams a cleaner path than a one-off Redpanda demo:

- cluster creation is tied back to a shared AVM baseline
- broker placement is explicit and production-minded from day one
- storage and listener choices are visible in source control
- the repo supports both portal-first and CLI-first operators
- the same implementation assets drive the technical blog content

That is the kind of blueprint that can actually grow with a platform team instead of getting thrown away after the first proof of concept.
