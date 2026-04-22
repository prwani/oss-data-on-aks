# Apache Kafka `az` CLI deployment path

Use this guide for the automation-first path. It assumes you want the AKS resource shape, Kubernetes assets, and Helm configuration tracked in source control.

## Prerequisites

- Azure CLI
- `kubectl`
- Helm 3.8+
- Terraform 1.11+ if you want the Terraform path
- an Azure subscription with quota for AKS, managed disks, and three user-pool nodes

## Environment variables

```bash
export LOCATION=eastus
export RESOURCE_GROUP=rg-apache-kafka-aks-dev
export CLUSTER_NAME=aks-apache-kafka-dev
export KAFKA_NAMESPACE=kafka
export KAFKA_HELM_VERSION=32.4.4
```

## Option A: Bicep wrapper

Create the resource group and run the workload wrapper:

```bash
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

This path relies on the shared AVM wrapper for the AKS baseline and provisions `systempool` plus the dedicated `kafka` user pool.

## Option B: Terraform wrapper

```bash
cd workloads/streaming/apache-kafka/infra/terraform
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform plan
terraform apply
```

The example `terraform.tfvars.example` provisions the same `systempool` and `kafka` pool shape as the Bicep wrapper.

## Connect to AKS

```bash
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME"
```

## Prepare the storage class and namespace

```bash
kubectl apply -f workloads/streaming/apache-kafka/kubernetes/manifests/managed-csi-premium-storageclass.yaml
kubectl apply -f workloads/streaming/apache-kafka/kubernetes/manifests/namespace.yaml
```

The storage class manifest creates the `managed-csi-premium` class expected by the Helm values even when the AKS baseline only exposes a default CSI class.

## Create the Kafka auth secret

The checked-in values file expects an existing secret named `kafka-auth`. Generate concrete passwords instead of checking a secret manifest into source control:

```bash
export KAFKA_CLIENT_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
export KAFKA_INTERBROKER_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
export KAFKA_CONTROLLER_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"

kubectl create secret generic kafka-auth \
  --namespace "$KAFKA_NAMESPACE" \
  --from-literal=client-passwords="$KAFKA_CLIENT_PASSWORD" \
  --from-literal=inter-broker-password="$KAFKA_INTERBROKER_PASSWORD" \
  --from-literal=controller-password="$KAFKA_CONTROLLER_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -
```

The Helm values create one client user named `platform-client`, so the `client-passwords` literal contains exactly one password.

## Install Kafka in KRaft mode

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm upgrade --install kafka bitnami/kafka \
  --version "$KAFKA_HELM_VERSION" \
  --namespace "$KAFKA_NAMESPACE" \
  --values workloads/streaming/apache-kafka/kubernetes/helm/kafka-values.yaml
```

The checked-in values assume:

- chart `32.4.4`
- Kafka `4.0.0`
- 3 controller-only pods
- 3 broker-only pods
- Premium SSD-backed PVCs
- node selectors and tolerations that target the `kafka` AKS pool
- `ClusterIP` service exposure only

## Validate the rollout

```bash
kubectl get pods -n "$KAFKA_NAMESPACE"
kubectl get pvc -n "$KAFKA_NAMESPACE"
kubectl get svc -n "$KAFKA_NAMESPACE"
kubectl get secret kafka-kraft -n "$KAFKA_NAMESPACE"
kubectl rollout status statefulset/kafka-controller -n "$KAFKA_NAMESPACE" --timeout=10m
kubectl rollout status statefulset/kafka-broker -n "$KAFKA_NAMESPACE" --timeout=10m
```

For this workload, `kubectl get pvc` is a first-class validation step. Controllers and brokers both depend on their own Azure Disk-backed PVCs.

## Validate client connectivity with a real topic

Create a local client config, start a short-lived Kafka client pod, create a topic, and describe it:

```bash
cat > client.properties <<EOF
security.protocol=SASL_PLAINTEXT
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="platform-client" password="${KAFKA_CLIENT_PASSWORD}";
EOF

kubectl run kafka-client \
  --namespace "$KAFKA_NAMESPACE" \
  --image docker.io/bitnami/kafka:4.0.0-debian-12-r10 \
  --restart=Never \
  --command -- sleep 3600

kubectl wait --for=condition=Ready pod/kafka-client -n "$KAFKA_NAMESPACE" --timeout=180s
kubectl cp client.properties "$KAFKA_NAMESPACE"/kafka-client:/client.properties

kubectl exec -n "$KAFKA_NAMESPACE" kafka-client -- bash -lc '
/opt/bitnami/kafka/bin/kafka-topics.sh \
  --bootstrap-server kafka:9092 \
  --command-config /client.properties \
  --create \
  --if-not-exists \
  --topic orders \
  --partitions 6 \
  --replication-factor 3
'

kubectl exec -n "$KAFKA_NAMESPACE" kafka-client -- bash -lc '
/opt/bitnami/kafka/bin/kafka-topics.sh \
  --bootstrap-server kafka:9092 \
  --command-config /client.properties \
  --describe \
  --topic orders
'

kubectl delete pod kafka-client -n "$KAFKA_NAMESPACE" --wait=true
rm client.properties
```

## Implementation notes

- The default Helm values require the `kafka` AKS pool to have **3 schedulable nodes** because both the controller and broker StatefulSets use hard anti-affinity.
- The `kafka-kraft` secret and the retained PVCs are both part of the cluster identity. Keep them aligned during upgrades and recoveries.
- External access is intentionally disabled. If you later expose Kafka outside the cluster, plan stable broker-specific advertised endpoints before you change the service topology.
