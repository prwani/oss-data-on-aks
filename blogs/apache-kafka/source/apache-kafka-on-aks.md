# Running Apache Kafka on AKS with KRaft, dedicated node pools, and an AKS AVM baseline

**Publication target:** Microsoft TechCommunity > Azure > Linux and Open Source Blog

## Summary

Apache Kafka can be installed on Kubernetes quickly, but a reusable AKS blueprint has to cover more than `helm install`. Kafka on AKS needs controller quorum design, broker disks, listener planning, and stateful upgrade discipline. This repository now includes a starter blueprint that uses AKS Azure Verified Modules (AVM) for the cluster foundation and a pinned Bitnami Kafka chart in KRaft mode with three controllers, three brokers, Premium SSD-backed PVCs, and internal-only exposure by default.

The goal is not to pretend every day-2 concern is solved forever. The goal is to give platform teams a clean Azure-first baseline they can evolve without starting from a throwaway lab.

## Why Kafka on AKS is worth standardizing

Kafka is a strong fit for AKS when teams want Kubernetes-native operations while still using Azure-native building blocks for:

- managed Kubernetes control plane operations
- dedicated node pools for workload placement
- Azure Disk CSI for durable broker storage
- Azure networking controls around private access
- shared infrastructure patterns that can be reused across workloads

The catch is that Kafka is not just another HTTP service.

## What makes Kafka on AKS different from a stateless app

This is the point I want readers to notice early: **Kafka on AKS is not a normal stateless microservice deployment**.

A typical AKS microservice often looks like this:

- one or more `Deployment`s
- replicas that can restart almost anywhere
- little or no per-pod durable storage
- one service endpoint that hides pod identity

Kafka is different:

- **KRaft controllers** maintain cluster metadata and quorum state
- **brokers** keep partition logs on their own PVC-backed Azure Disks
- **clients bootstrap once and then connect to broker-specific advertised endpoints**
- **retention capacity** depends on replication factor and free-space headroom, not only raw disk size
- **upgrades** need to preserve quorum and avoid long-lived under-replicated partitions

That is why the Kafka blueprint in this repo validates `kubectl get pvc`, controller quorum, and a real topic workflow instead of stopping at `kubectl get pods`.

## The AKS pattern used in this repo

The checked-in implementation uses this starting point:

| Layer | Recommendation | Why |
| --- | --- | --- |
| AKS baseline | Shared AVM wrapper | Keeps cluster creation consistent across workloads |
| Node pools | `systempool` plus a dedicated `kafka` pool | Separates AKS add-ons from Kafka data-plane pods |
| Controllers | 3 controller-only pods | Makes the KRaft quorum explicit |
| Brokers | 3 broker-only pods | Gives a straightforward RF=3 starting point |
| Storage | Premium SSD-backed Azure Disk PVCs | Better fit for Kafka log I/O and recovery |
| Exposure | `ClusterIP` bootstrap service only | Internal-first by default |
| Recovery | Retain PVCs and the `kafka-kraft` secret | Protects cluster identity during controlled recovery |

A deliberate detail here is the **single dedicated `kafka` node pool with three nodes**. Each node can host one controller and one broker, which keeps the starting footprint practical while still letting both StatefulSets use hard anti-affinity.

## Why KRaft matters in the starter blueprint

This blueprint uses **KRaft mode**, so ZooKeeper is removed from the topology. That simplifies the platform shape, but it also makes the controller quorum part of the runtime contract. The chart creates a `kafka-kraft` secret on first install, and that secret belongs in the same conversation as retained PVCs and controlled upgrades.

In other words, a Kafka platform blueprint on AKS now has to treat quorum metadata as first-class state.

## What the repo now provides

The Kafka workload in the repo is organized around five practical building blocks:

1. a shared AKS baseline under `platform/aks-avm`
2. workload wrappers for Terraform and Bicep under `workloads/streaming/apache-kafka/infra`
3. deployment guidance for portal-first and CLI-first operators under `workloads/streaming/apache-kafka/docs`
4. Helm values and Kubernetes manifests under `workloads/streaming/apache-kafka/kubernetes`
5. a publishable blog package under `blogs/apache-kafka`

That split is important. It lets the cluster baseline stay reusable while the Kafka-specific stateful guidance lives with the workload.

## Deploy the AKS baseline

The repo keeps both IaC entry points visible.

### Bicep path

```bash
export LOCATION=eastus
export RESOURCE_GROUP=rg-apache-kafka-aks-dev
export CLUSTER_NAME=aks-apache-kafka-dev

az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file workloads/streaming/apache-kafka/infra/bicep/main.bicep \
  --parameters \
      clusterName="$CLUSTER_NAME" \
      location="$LOCATION"
```

### Terraform path

```bash
cd workloads/streaming/apache-kafka/infra/terraform
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform plan
terraform apply
```

Both wrappers create `systempool` plus a dedicated `kafka` pool with three nodes so the checked-in Helm values can land cleanly.

## Create the namespace and auth secret

Once AKS is ready, connect to the cluster and apply the Kubernetes-native prerequisites:

```bash
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME"

kubectl apply -f workloads/streaming/apache-kafka/kubernetes/manifests/managed-csi-premium-storageclass.yaml
kubectl apply -f workloads/streaming/apache-kafka/kubernetes/manifests/namespace.yaml
```

The blueprint does **not** check a secret manifest into the repo. Instead it generates passwords at deploy time:

```bash
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

That keeps the repo concrete without hardcoding fake secrets.

## Install Kafka with the pinned chart version

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm upgrade --install kafka bitnami/kafka \
  --version 32.4.4 \
  --namespace kafka \
  --values workloads/streaming/apache-kafka/kubernetes/helm/kafka-values.yaml
```

The checked-in values do four important things:

- keep the runtime in **KRaft mode**
- deploy **3 controller-only pods** and **3 broker-only pods**
- bind both tiers to `managed-csi-premium`
- keep the bootstrap service **internal-only**

## Validate the parts that matter for Kafka

First, validate the stateful platform shape:

```bash
kubectl get pods -n kafka
kubectl get pvc -n kafka
kubectl get svc -n kafka
kubectl get secret kafka-kraft -n kafka
kubectl rollout status statefulset/kafka-controller -n kafka --timeout=10m
kubectl rollout status statefulset/kafka-broker -n kafka --timeout=10m
```

For Kafka, the PVC check is not optional. Controllers and brokers both need their own Azure Disk-backed claims.

Then validate a real client flow with a short-lived Kafka client pod:

```bash
cat > client.properties <<EOF
security.protocol=SASL_PLAINTEXT
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="platform-client" password="${KAFKA_CLIENT_PASSWORD}";
EOF

kubectl run kafka-client \
  --namespace kafka \
  --image docker.io/bitnami/kafka:4.0.0-debian-12-r10 \
  --restart=Never \
  --command -- sleep 3600

kubectl wait --for=condition=Ready pod/kafka-client -n kafka --timeout=180s
kubectl cp client.properties kafka/kafka-client:/client.properties

kubectl exec -n kafka kafka-client -- bash -lc '
/opt/bitnami/kafka/bin/kafka-topics.sh \
  --bootstrap-server kafka:9092 \
  --command-config /client.properties \
  --create \
  --if-not-exists \
  --topic orders \
  --partitions 6 \
  --replication-factor 3
'

kubectl exec -n kafka kafka-client -- bash -lc '
/opt/bitnami/kafka/bin/kafka-topics.sh \
  --bootstrap-server kafka:9092 \
  --command-config /client.properties \
  --describe \
  --topic orders
'

kubectl delete pod kafka-client -n kafka --wait=true
rm client.properties
```

That is much closer to a real validation path than just checking whether the pods say `Running`.

## The AKS-specific differences to keep in mind

If you are used to deploying stateless services, these Kafka-on-AKS behaviors are the ones to internalize:

1. **KRaft controller quorum is stateful platform logic**, not a side detail.
2. **Broker disks are the workload**, so disk growth and retention planning belong in the first design review.
3. **Listener topology matters** because Kafka clients need broker-specific endpoints, not just one VIP.
4. **Upgrades are operational events**, not just Helm churn, because ISR health and quorum stability matter during rollout.
5. **Disaster recovery is broader than PVC recovery**. A second cluster or replication strategy matters more than a blind volume snapshot.

That is exactly what makes Kafka on AKS different from a typical stateless app.

## A note on Azure Storage integrations

This starter blueprint intentionally avoids creating an Azure Storage account because broker data lives on Azure Disk PVCs. If you later add Kafka Connect sinks, archival, or any other Azure Storage integration, use **AKS Workload Identity and managed identity-based auth only**. Shared keys do not belong in the pattern.

## Where this goes next

This workload now feels like a real blueprint instead of a scaffold: shared AKS infrastructure wrappers, pinned chart guidance, concrete manifests, stateful validation steps, and publication-ready documentation.

The next layer of maturity is environment-specific: observability integration, external listener design, and multi-cluster recovery posture. But the starter platform is now in the repo, and it is grounded in what makes Kafka on AKS different from a normal stateless deployment.
