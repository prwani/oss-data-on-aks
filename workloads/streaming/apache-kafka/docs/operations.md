# Apache Kafka operations notes

Operational maturity for Kafka should cover more than pod health.

## Daily and weekly signals

| Area | What to watch |
| --- | --- |
| KRaft quorum | controller leader elected, all 3 voters online, no churn in controller logs |
| Broker health | broker count, restarts, ISR stability, under-replicated partitions |
| Storage | PVC binding, broker disk usage, retention runway, Azure Disk saturation |
| Client path | bootstrap service stays internal, topic create/list flows still succeed |
| Upgrades | one pod at a time, no quorum loss, no prolonged ISR shrink after rollouts |
| Security | secret rotation, internal-only exposure, no drift toward shared-key Azure integrations |

## First checks after install, upgrade, or node maintenance

```bash
kubectl get pods -n kafka -o wide
kubectl get pvc -n kafka
kubectl get svc -n kafka
kubectl get statefulset -n kafka
kubectl get secret kafka-kraft -n kafka
```

For log-based confirmation:

```bash
kubectl logs kafka-controller-0 -n kafka --tail=50
kubectl logs kafka-broker-0 -n kafka --tail=50
```

In the controller logs, look for stable leader or follower transitions rather than repeated elections. In the broker logs, look for successful broker startup and registration rather than repeated reconnect loops.

## Rebuild a local client configuration

If you no longer have the client password from initial deployment, recover it from the Kubernetes secret and recreate the local `client.properties` file:

```bash
export KAFKA_NAMESPACE=kafka
export KAFKA_CLIENT_PASSWORD="$(
  kubectl get secret kafka-auth -n "$KAFKA_NAMESPACE" -o jsonpath='{.data.client-passwords}' \
  | python3 -c 'import base64,sys; print(base64.b64decode(sys.stdin.read()).decode())'
)"

cat > client.properties <<EOF
security.protocol=SASL_PLAINTEXT
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="platform-client" password="${KAFKA_CLIENT_PASSWORD}";
EOF
```

## Create a reusable client pod

```bash
kubectl run kafka-client \
  --namespace "$KAFKA_NAMESPACE" \
  --image docker.io/bitnami/kafka:4.0.0-debian-12-r10 \
  --restart=Never \
  --command -- sleep 3600

kubectl wait --for=condition=Ready pod/kafka-client -n "$KAFKA_NAMESPACE" --timeout=180s
kubectl cp client.properties "$KAFKA_NAMESPACE"/kafka-client:/client.properties
```

## Check topic and replica health

List topics:

```bash
kubectl exec -n "$KAFKA_NAMESPACE" kafka-client -- bash -lc '
/opt/bitnami/kafka/bin/kafka-topics.sh \
  --bootstrap-server kafka:9092 \
  --command-config /client.properties \
  --list
'
```

Check for under-replicated partitions:

```bash
kubectl exec -n "$KAFKA_NAMESPACE" kafka-client -- bash -lc '
/opt/bitnami/kafka/bin/kafka-topics.sh \
  --bootstrap-server kafka:9092 \
  --command-config /client.properties \
  --describe \
  --under-replicated-partitions
'
```

Describe a critical topic:

```bash
kubectl exec -n "$KAFKA_NAMESPACE" kafka-client -- bash -lc '
/opt/bitnami/kafka/bin/kafka-topics.sh \
  --bootstrap-server kafka:9092 \
  --command-config /client.properties \
  --describe \
  --topic orders
'
```

## Check KRaft quorum status

Recover the controller password and query the metadata quorum directly from a controller pod:

```bash
export KAFKA_CONTROLLER_PASSWORD="$(
  kubectl get secret kafka-auth -n "$KAFKA_NAMESPACE" -o jsonpath='{.data.controller-password}' \
  | python3 -c 'import base64,sys; print(base64.b64decode(sys.stdin.read()).decode())'
)"

kubectl exec -n "$KAFKA_NAMESPACE" kafka-controller-0 -- bash -lc '
cat > /bitnami/kafka/controller-admin.properties <<EOF
security.protocol=SASL_PLAINTEXT
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="controller_user" password="'"$KAFKA_CONTROLLER_PASSWORD"'";
EOF
/opt/bitnami/kafka/bin/kafka-metadata-quorum.sh \
  --bootstrap-controller localhost:9093 \
  --command-config /bitnami/kafka/controller-admin.properties \
  describe --status
rm -f /bitnami/kafka/controller-admin.properties
'
```

Healthy output should show three voters and one current leader.

## Storage and retention guidance

Prefer these steps over reactive firefighting:

1. increase broker disk or broker count before you cross sustained 70% to 75% used capacity
2. keep free space available for compaction, segment roll, and replica recovery
3. remember that replication factor 3 means usable single-copy retention is only a fraction of raw disk capacity
4. treat controller disks separately from broker disks; controller storage growth usually signals metadata problems, not normal topic growth

## Upgrade guidance

Before a chart or Kafka version upgrade:

1. confirm all six PVCs are `Bound`
2. confirm the KRaft quorum is healthy
3. confirm the under-replicated-partitions command returns no long-lived output
4. keep the `kafka-kraft` secret aligned with retained PVCs

Run the upgrade with the pinned values file:

```bash
helm upgrade kafka bitnami/kafka \
  --version 32.4.4 \
  --namespace kafka \
  --values workloads/streaming/apache-kafka/kubernetes/helm/kafka-values.yaml
```

Then watch both StatefulSets until they settle:

```bash
kubectl rollout status statefulset/kafka-controller -n kafka --timeout=10m
kubectl rollout status statefulset/kafka-broker -n kafka --timeout=10m
```

## Backup and disaster recovery note

Kafka durability is broader than PVC durability:

- PVCs and the `kafka-kraft` secret help with same-cluster recovery
- they do **not** replace a disaster-recovery plan
- for DR, use a secondary Kafka cluster, topic replication, producer replay, or another workload-appropriate replication model
- if you export Kafka data to Azure Storage through another component, use managed identity or workload identity instead of shared keys

## Recommended runbooks

- replace a failed broker while preserving its PVC identity
- recover from persistent under-replicated partitions
- validate controller quorum after an AKS node image upgrade
- rotate the `kafka-auth` secret and restart the release cleanly
- review retention settings when disk growth outpaces forecast

## Cleanup of the client pod

```bash
kubectl delete pod kafka-client -n "$KAFKA_NAMESPACE" --wait=true
rm client.properties
```
