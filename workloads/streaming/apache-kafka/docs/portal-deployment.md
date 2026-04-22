# Apache Kafka portal deployment path

Use this guide when the team wants to validate the Azure resource shape in the portal before settling into full automation.

## Outcome

You should end with:

- an AKS cluster aligned to the shared AVM baseline
- `systempool` plus a dedicated `kafka` user pool with 3 nodes
- a `kafka` namespace
- one Helm release named `kafka`
- 3 KRaft controllers and 3 brokers backed by Premium SSD PVCs
- internal-only Kafka bootstrap access by default

## Step 1: Review the blueprint assets

Before you click through the portal, review the implementation artifacts that define the target state:

- architecture: `docs/architecture.md`
- Helm values: `kubernetes/helm/kafka-values.yaml`
- namespace and storage class manifests: `kubernetes/manifests/*.yaml`
- CLI and operations guidance: `docs/az-cli-deployment.md` and `docs/operations.md`

This matters more for Kafka than for a stateless app because controller quorum, per-broker storage, and listener topology are part of the design contract, not afterthoughts.

## Step 2: Create or select the resource group

If you are using the portal-first path, create the resource group up front and keep its name aligned with the workload wrappers so the same environment can later be automated without renaming.

Suggested naming:

- resource group: `rg-apache-kafka-aks-dev`
- cluster: `aks-apache-kafka-dev`

## Step 3: Create the AKS cluster in the portal

Use the portal to mirror the AVM-oriented design choices:

1. choose the target region
2. enable managed identity
3. enable Azure Monitor integration if your environment expects it
4. keep the cluster API private if that matches your environment constraints
5. create `systempool`
6. add a user pool named `kafka`

### Suggested pool intent

| Pool | Purpose | Notes |
| --- | --- | --- |
| `systempool` | AKS add-ons and control-plane-adjacent workloads | keep Kafka data-plane pods off this pool |
| `kafka` | Kafka controllers and brokers | start with 3 nodes so both StatefulSets can satisfy hard anti-affinity |

Recommended starting shape for the `kafka` pool:

- VM size: `Standard_D4s_v5`
- node count: `3`
- taint: `dedicated=kafka:NoSchedule`

The checked-in Helm values target AKS's `agentpool=kafka` label and tolerate the `dedicated=kafka:NoSchedule` taint.

## Step 4: Connect to the cluster

Once the cluster is provisioned, use Cloud Shell or a local terminal:

```bash
az aks get-credentials \
  --resource-group rg-apache-kafka-aks-dev \
  --name aks-apache-kafka-dev
```

## Step 5: Create the storage class, namespace, and auth secret

Apply the Premium storage class and namespace first, then create the Kafka auth secret:

```bash
kubectl apply -f workloads/streaming/apache-kafka/kubernetes/manifests/managed-csi-premium-storageclass.yaml
kubectl apply -f workloads/streaming/apache-kafka/kubernetes/manifests/namespace.yaml

export KAFKA_CLIENT_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
export KAFKA_INTERBROKER_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
export KAFKA_CONTROLLER_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"

kubectl create secret generic kafka-auth \
  --namespace kafka \
  --from-literal=client-passwords="$KAFKA_CLIENT_PASSWORD" \
  --from-literal=inter-broker-password="$KAFKA_INTERBROKER_PASSWORD" \
  --from-literal=controller-password="$KAFKA_CONTROLLER_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -
```

No secret YAML is checked into the repo on purpose.

## Step 6: Install Kafka

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm upgrade --install kafka bitnami/kafka \
  --version 32.4.4 \
  --namespace kafka \
  --values workloads/streaming/apache-kafka/kubernetes/helm/kafka-values.yaml
```

The chart deploys Kafka in **KRaft mode**, so there is no ZooKeeper tier to provision or manage.

## Step 7: Validate the deployment

```bash
kubectl get pods -n kafka
kubectl get pvc -n kafka
kubectl get svc -n kafka
kubectl get secret kafka-kraft -n kafka
kubectl rollout status statefulset/kafka-controller -n kafka --timeout=10m
kubectl rollout status statefulset/kafka-broker -n kafka --timeout=10m
```

Check for:

- three controller pods and three broker pods scheduled and healthy
- six PVCs bound to `managed-csi-premium`
- no unintended public endpoint for the bootstrap service
- the chart-generated `kafka-kraft` secret present after first install

## Portal-specific review points

- confirm the `kafka` pool has the expected VM size, node count, and taint
- confirm the cluster is not exposing Kafka through a public service by accident
- confirm the managed disks are provisioning in the expected region and SKU
- confirm your retention target still fits the 3 x 256 GiB broker-disk starting point once replication and free-space headroom are applied
