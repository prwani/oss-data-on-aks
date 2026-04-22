# Redpanda architecture notes

Redpanda should be treated as a stateful streaming platform, not as a generic stateless deployment.

## Why this workload needs a different AKS design

Redpanda combines broker-local log storage, low-latency I/O, per-broker listener identity, and CPU instruction set requirements. That means the AKS design should optimize for:

- predictable disk latency and throughput
- one broker per dedicated node
- stable internal listener addressing
- cert-manager-backed TLS
- safe rolling maintenance and broker recovery

## Recommended reference architecture

```text
+--------------------------------------------------------------------+
| AKS cluster                                                        |
|                                                                    |
|  systempool                                                        |
|   - coredns and AKS add-ons                                        |
|   - cert-manager                                                   |
|   - Helm post-install jobs                                         |
|                                                                    |
|  rpbroker                                                          |
|   - 3 dedicated user-pool nodes                                    |
|   - Helm release: redpanda                                         |
|   - 3 Redpanda brokers (StatefulSet)                               |
|   - one broker per node                                            |
|   - Premium SSD-backed PVC per broker                              |
|                                                                    |
|  Internal listener surface                                         |
|   - admin API, Kafka API, Schema Registry, PandaProxy              |
|   - ClusterIP and headless services only by default                |
|                                                                    |
|  External listener surface                                         |
|   - intentionally disabled in the checked-in values                |
|   - design later around private routing and stable advertised IPs  |
+--------------------------------------------------------------------+
```

## Design decisions

| Area | Recommendation | Notes |
| --- | --- | --- |
| Cluster baseline | Use AKS AVM wrappers | Keeps Redpanda aligned with the rest of the repo |
| Broker pool | Dedicated `rpbroker` pool with 3 nodes | Matches the default 3-broker StatefulSet and hard anti-affinity |
| CPU family | Use `Standard_D8ds_v5` or equivalent x86_64 SSE4.2-capable SKU | Redpanda fails fast on unsupported CPUs |
| Storage | Use `managed-csi-premium` and 256 GiB PVCs | Sensible starter shape for durable broker storage |
| Listener exposure | Keep external access disabled by default | Reduces attack surface and avoids premature advertised-listener complexity |
| TLS | Keep chart TLS enabled and install cert-manager first | Chart `26.1.1` expects cert-manager-managed certificates |
| Authentication | Leave SASL off in repo values | Keeps the repo secret-free; create secrets out of band before enabling |
| Pod security | Use a dedicated namespace with privileged PSA labels | `tuning.tune_aio_events` creates a privileged tuning container |
| Tiered storage | Keep it off in the starter values | Enable later only with Azure Blob access through managed identity |

## AKS-specific guidance

### 1. Dedicated node pool and sizing

The checked-in wrappers provision:

- `systempool` with 1 node for cert-manager, add-ons, and Helm jobs
- `rpbroker` with 3 nodes for the Redpanda brokers

The default broker pool size is `Standard_D8ds_v5`, which gives the starter blueprint enough headroom for 4 dedicated Redpanda cores and 12 GiB of container memory per broker. If you substitute another SKU, keep these rules:

- stay on **x86_64**
- keep **SSE4.2** support
- keep at least **3 schedulable broker nodes**
- keep the pool taint aligned to `dedicated=redpanda-broker:NoSchedule`

### 2. Storage choices

Use Azure Disk CSI for the primary broker data path and treat `managed-csi-premium` as the baseline storage class. The checked-in values request one 256 GiB Premium SSD-backed PVC per broker.

For heavier workloads, revisit both PVC size and disk SKU. Premium SSD v2 or larger Premium SSD tiers can materially improve latency and throughput, but the important part of the starter blueprint is the **per-broker PVC model** and the explicit storage class, not the exact capacity number.

### 3. Listener exposure and service strategy

The checked-in values keep `external.enabled: false`, so Redpanda starts with internal-only admin, Kafka, Schema Registry, and HTTP listener surfaces.

That is intentional. Redpanda external access is not just a service-type choice; it is also an **advertised-listener design** problem. Each broker needs a stable address that producers and consumers can reach. On AKS, plan this before you enable external listeners:

- how each broker advertises a stable name or IP
- whether clients stay private to the VNet
- whether NodePort or a private LoadBalancer adds acceptable latency
- how TLS and SASL policies map to those external paths

### 4. TLS and authentication

The starter values keep:

- **TLS enabled**
- **SASL disabled**

That gives you encrypted internal traffic without checking secrets into the repo. It also means **cert-manager is a prerequisite** before the Helm install. When you are ready for stronger client authentication, create the SASL secret outside the repo and use a private overlay to turn `auth.sasl.enabled` on.

### 5. Namespace and privileged tuning

The Redpanda chart keeps `tuning.tune_aio_events: true` by default, and this blueprint leaves it enabled. That path creates a privileged tuning container so the namespace manifest labels the `redpanda` namespace with the `privileged` Pod Security profile.

This is a useful AKS-specific callout: unlike a typical stateless app, the Redpanda install path touches node-level kernel limits to improve broker I/O behavior.

### 6. Availability zones and rack awareness

The wrappers do not hardwire zones so the blueprint stays portable across regions, but the chart already includes topology spread behavior. If your region supports zones and your availability target requires it:

- spread the `rpbroker` pool across zones
- keep one broker per zone where possible
- consider turning on `rackAwareness.enabled: true`

### 7. Tiered storage boundary

The checked-in values keep `storage.tiered` off. When you enable tiered storage on Azure, use Azure Blob with **managed identity-based access** and the minimum required RBAC. Do not fall back to storage account shared keys.

## Capacity planning starter values

| Component | Starter value | Why |
| --- | --- | --- |
| System pool | `1 x Standard_D4ds_v5` | Enough room for add-ons and cert-manager without stealing broker capacity |
| Broker pool | `3 x Standard_D8ds_v5` | Supports 3 brokers with one broker per node |
| Brokers | `3` replicas | Baseline quorum and replication shape |
| CPU per broker | `4` cores | Matches Redpanda guidance to use full cores |
| Memory per broker | `12 GiB` | Leaves room for Redpanda and supporting processes |
| PVC per broker | `256 GiB` | Starter capacity with Premium SSD-backed storage |
| Service exposure | Internal only | Safer default than public listeners |

These are starter values, not production sizing guidance. Tune them against ingress rate, partition count, retention, compaction, and recovery targets.
