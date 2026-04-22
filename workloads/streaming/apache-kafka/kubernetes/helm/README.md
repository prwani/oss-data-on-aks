# Apache Kafka Helm assets

This folder contains the pinned Helm values used by the Kafka blueprint.

## Release contract

- chart: `bitnami/kafka` `32.4.4`
- Kafka runtime: `4.0.0`
- release name: `kafka`
- namespace: `kafka`
- mode: **KRaft** with ZooKeeper removed
- topology: **3 controller-only pods + 3 broker-only pods**

## Install sequence

```bash
export CHART_VERSION=32.4.4
export KAFKA_NAMESPACE=kafka

kubectl apply -f workloads/streaming/apache-kafka/kubernetes/manifests/managed-csi-premium-storageclass.yaml
kubectl apply -f workloads/streaming/apache-kafka/kubernetes/manifests/namespace.yaml

export KAFKA_CLIENT_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
export KAFKA_INTERBROKER_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
export KAFKA_CONTROLLER_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"

kubectl create secret generic kafka-auth \
  --namespace "$KAFKA_NAMESPACE" \
  --from-literal=client-passwords="$KAFKA_CLIENT_PASSWORD" \
  --from-literal=inter-broker-password="$KAFKA_INTERBROKER_PASSWORD" \
  --from-literal=controller-password="$KAFKA_CONTROLLER_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm upgrade --install kafka bitnami/kafka \
  --version "$CHART_VERSION" \
  --namespace "$KAFKA_NAMESPACE" \
  --values workloads/streaming/apache-kafka/kubernetes/helm/kafka-values.yaml
```

## Notes

- the values file targets the AKS `agentpool=kafka` label and tolerates `dedicated=kafka:NoSchedule`
- `controller.controllerOnly=true` creates separate `kafka-controller` and `kafka-broker` StatefulSets
- the chart creates the `kafka-kraft` secret on first install; keep it if the PVCs are retained
- the bootstrap service stays `ClusterIP` and `externalAccess` remains disabled by default
- if you later expose Kafka outside the cluster, plan stable broker-specific advertised endpoints before changing the service topology
- the workload does not check any Azure Storage credential material into the repo; future Azure Storage integrations should use managed identity or workload identity
