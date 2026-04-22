# Redpanda operations notes

Operational maturity for Redpanda should cover more than pod health.

## Daily and weekly signals

| Area | What to watch | Starter command |
| --- | --- | --- |
| Broker placement | three brokers ready and placed on `rpbroker` nodes | `kubectl get pods -n redpanda -o wide` |
| PVC health | all broker claims `Bound`, no unexpected churn | `kubectl get pvc -n redpanda` |
| TLS state | cert-manager resources `Ready` and not near expiry | `kubectl get certificates -n redpanda` |
| Admin API | cluster ready and health endpoint reachable | `curl -sk https://127.0.0.1:9644/v1/status/ready` |
| Exposure drift | no unintended public service shape | `kubectl get svc -n redpanda` |
| Node pool health | `rpbroker` nodes ready and not under maintenance pressure | `kubectl get nodes -l agentpool=rpbroker` |

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

Prefer these steps over ad hoc resizing:

1. scale the `rpbroker` node pool before or together with broker replica changes
2. keep one broker per node as the default operational model
3. expand PVC capacity before disks become the limiting factor for retention
4. revisit CPU and memory sizing together because Redpanda uses a thread-per-core model

Azure Disk CSI supports volume expansion, so the storage class is configured with `allowVolumeExpansion: true`. Even with that flexibility, plan changes carefully and validate broker recovery after expansion or node moves.

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
- rotate cert-manager issuers or move to bring-your-own certificates
- enable and rotate SASL users
- validate the cluster after an AKS node image upgrade
