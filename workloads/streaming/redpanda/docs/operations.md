# Redpanda operations notes

Operational maturity for Redpanda should cover more than pod health.

## Daily and weekly signals

| Area | What to watch | Starter command |
| --- | --- | --- |
| Broker placement | three brokers ready and placed on `rpbroker` nodes | `kubectl get pods -n redpanda -o wide` |
| PVC health | all broker claims `Bound`, no unexpected churn | `kubectl get pvc -n redpanda` |
| TLS state | cert-manager resources `Ready` and not near expiry | `kubectl get certificates -n redpanda` |
| Admin API | cluster ready and health endpoint reachable | `curl -sk https://127.0.0.1:9644/v1/status/ready` |
| Disk capacity | broker disk utilization trending toward warning threshold | `rpk cluster logdirs describe` or Azure Monitor disk metrics |
| Under-replicated partitions | zero under-replicated partitions | `rpk cluster health` |
| Exposure drift | no unintended public service shape | `kubectl get svc -n redpanda` |
| Node pool health | `rpbroker` nodes ready, cluster autoscaler activity | `kubectl get nodes -l agentpool=rpbroker` |

## Validation commands

```bash
kubectl get pods -n redpanda -o wide
kubectl get pvc -n redpanda
kubectl get certificates -n redpanda
kubectl get svc -n redpanda
kubectl rollout status statefulset/redpanda -n redpanda
```

For admin API checks without changing the listener posture:

```bash
kubectl port-forward svc/redpanda 9644:9644 -n redpanda
curl -sk https://127.0.0.1:9644/v1/status/ready
curl -sk https://127.0.0.1:9644/v1/cluster/health_overview
```

Unlike a stateless microservice, the PVC and broker-placement checks are mandatory here. A pod in `Running` is not enough if its Azure Disk is churned, attached to the wrong node pool, or close to capacity.

## Scaling guidance

Redpanda is a stateful broker cluster. Unlike stateless compute engines, horizontal scaling involves partition rebalancing and data movement. Prefer deliberate, validated scaling over automatic or ad hoc changes.

### Scaling priority order

1. **expand PVC capacity first** — cheapest and least disruptive way to handle growing data
2. **increase VM SKU** — more CPU and memory per broker without rebalancing
3. **add brokers** — only when PVC and VM headroom are exhausted or partition distribution needs to change
4. keep one broker per node as the default operational model
5. revisit CPU and memory sizing together because Redpanda uses a thread-per-core model

### Capacity monitoring thresholds

| Metric | Warning (investigate) | Action (scale) | Notes |
| --- | --- | --- | --- |
| Disk utilization | 60% | 75% | Expand PVCs first; add brokers only if partition count requires it |
| CPU utilization | 70% sustained | 85% sustained | Consider increasing VM SKU before adding brokers |
| Producer latency (p99) | 2× baseline | 5× baseline | May indicate partition skew rather than capacity shortage |
| Under-replicated partitions | any | sustained | Fix before any scaling operation |
| Consumer lag | growing trend | growing trend + latency | Check partition distribution before adding brokers |

Track **growth rate**, not just instantaneous values. A disk at 50% that grows 5% per day is more urgent than a disk at 65% that is stable.

### AKS cluster autoscaler for the rpbroker pool

Enable the AKS cluster autoscaler so that when you manually scale the StatefulSet, nodes are provisioned automatically:

```bash
az aks nodepool update \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --name rpbroker \
  --enable-cluster-autoscaler \
  --min-count 3 \
  --max-count 6
```

The `3–6` range is a starter ceiling, not a general recommendation. Adjust `max-count` based on your quota, partition count, and expected throughput. The cluster autoscaler does **not** automatically scale the Redpanda StatefulSet — it only ensures nodes exist when brokers are added or drained.

### Expanding broker PVC capacity

The storage class is configured with `allowVolumeExpansion: true`, so PVCs can be resized in place:

```bash
# Check current PVC sizes
kubectl get pvc -n redpanda

# Expand a broker PVC (example: broker 0)
kubectl patch pvc datadir-redpanda-0 -n redpanda \
  -p '{"spec":{"resources":{"requests":{"storage":"512Gi"}}}}'

# Repeat for each broker PVC
kubectl patch pvc datadir-redpanda-1 -n redpanda \
  -p '{"spec":{"resources":{"requests":{"storage":"512Gi"}}}}'
kubectl patch pvc datadir-redpanda-2 -n redpanda \
  -p '{"spec":{"resources":{"requests":{"storage":"512Gi"}}}}'

# Verify expansion (may take a few minutes for Azure Disk to resize)
kubectl get pvc -n redpanda
```

PVC expansion does not require broker restarts on Azure Disk CSI. This is the preferred first step before adding brokers.

### Adding brokers (scale out)

Before adding brokers, verify these preconditions:

- no under-replicated or offline partitions: check via `rpk cluster health` or the admin API
- the `rpbroker` pool has room for new nodes (or the AKS cluster autoscaler is enabled)
- the partition count is high enough to benefit from more brokers (adding a broker to a cluster with 3 partitions does not help)

Scale-out procedure:

```bash
# 1. Scale the rpbroker pool if the cluster autoscaler is not enabled
az aks nodepool update \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --name rpbroker \
  --node-count 5

# 2. Update the Helm values (statefulset.replicas) and upgrade
helm upgrade redpanda redpanda/redpanda \
  --version 26.1.1 \
  --namespace redpanda \
  --values workloads/streaming/redpanda/kubernetes/helm/redpanda-values.yaml \
  --set statefulset.replicas=5

# 3. Wait for new brokers to join
kubectl rollout status statefulset/redpanda -n redpanda --timeout=15m

# 4. Validate cluster health (port-forward first)
kubectl port-forward svc/redpanda 9644:9644 -n redpanda &
curl -sk https://127.0.0.1:9644/v1/cluster/health_overview

# 5. Rebalance partitions across the new brokers
kubectl exec -n redpanda redpanda-0 -c redpanda -- \
  rpk cluster partitions balancer-status
```

Capacity relief may lag until partition rebalancing completes. Monitor the admin API health overview and `rpk cluster partitions balancer-status` until the cluster stabilizes.

### Removing brokers (scale in / decommission)

Scaling down a stateful broker cluster requires decommissioning — you cannot simply reduce the StatefulSet replica count without migrating data first.

Before decommissioning, verify:

- broker count after removal stays ≥ the highest topic replication factor
- remaining brokers have enough disk and CPU headroom to absorb migrated partitions
- no under-replicated or offline partitions exist

Decommission procedure:

```bash
# 1. Identify the broker ID to decommission (highest numbered broker)
kubectl exec -n redpanda redpanda-0 -c redpanda -- \
  rpk cluster status

# 2. Decommission the broker (example: broker ID 4)
kubectl exec -n redpanda redpanda-0 -c redpanda -- \
  rpk redpanda admin brokers decommission 4

# 3. Monitor decommission progress (partitions migrating away)
kubectl exec -n redpanda redpanda-0 -c redpanda -- \
  rpk redpanda admin brokers decommission-status 4

# 4. Wait until decommission completes (all partitions moved)

# 5. Scale down the StatefulSet
helm upgrade redpanda redpanda/redpanda \
  --version 26.1.1 \
  --namespace redpanda \
  --values workloads/streaming/redpanda/kubernetes/helm/redpanda-values.yaml \
  --set statefulset.replicas=3

# 6. Delete orphaned PVCs
kubectl delete pvc datadir-redpanda-4 -n redpanda
kubectl delete pvc datadir-redpanda-3 -n redpanda

# 7. Scale down the rpbroker pool if needed
az aks nodepool update \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --name rpbroker \
  --node-count 3

# 8. Validate cluster health
kubectl exec -n redpanda redpanda-0 -c redpanda -- \
  rpk cluster health
```

> **Warning:** never scale down the StatefulSet before decommissioning completes. Premature removal causes data loss for partitions still hosted on the departing broker.

## Upgrade guidance

- pin tested chart and Redpanda versions
- keep cert-manager on a supported version before you move the Redpanda chart
- use one-broker-at-a-time rolling changes; the checked-in values keep `maxUnavailable: 1`
- validate admin API readiness, PVC state, and service shape after each upgrade

A safe starter command is:

```bash
helm upgrade --install redpanda redpanda/redpanda \
  --version 26.1.1 \
  --namespace redpanda \
  --values workloads/streaming/redpanda/kubernetes/helm/redpanda-values.yaml
```

## Listener, TLS, and authentication guidance

- the repo values keep **external listeners off**
- the repo values keep **TLS on**
- the repo values keep **SASL off**

That split keeps the starter cluster encrypted and secret-free, but it is not the final production posture. Before you onboard off-cluster clients:

- design a stable external address for **each broker**
- decide whether private NodePort or private LoadBalancer fits your latency and networking constraints
- create SASL credentials outside the repo and enable them through a private overlay
- replace or integrate the default cert-manager issuer if your environment requires enterprise PKI

## Tiered storage boundary

The checked-in values keep tiered storage disabled. When you enable Azure Blob-backed tiered storage:

- use managed identity or workload identity for data access
- grant the minimum Azure RBAC needed for the target container
- keep storage account shared keys out of the design

## AKS maintenance and node replacement

Treat AKS node maintenance as a workload event, not just a platform event:

- ensure replacement broker nodes stay on an **x86_64 SSE4.2-capable** VM family
- watch broker rescheduling and PVC attach/detach time during node image upgrades
- keep the `rpbroker` taint in place so general workloads do not land on broker nodes
- verify the admin API and PVCs after every planned or unplanned node move

## Recommended runbooks

- replace a failed broker node
- expand a broker PVC or adjust retention
- add brokers and rebalance partitions
- decommission a broker and scale down
- rotate cert-manager issuers or move to bring-your-own certificates
- enable and rotate SASL users
- validate the cluster after an AKS node image upgrade
- AKS cluster autoscaler not adding nodes (check limits, quotas, and pool max-count)
- investigate partition skew or hot partitions before scaling
