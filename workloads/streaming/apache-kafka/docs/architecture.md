# Apache Kafka architecture notes

Kafka on AKS should be treated as a durable streaming platform, not as a generic stateless deployment.

## Why this workload needs a different AKS design

Kafka combines controller quorum behavior, per-broker log storage, ordered upgrades, and client listener routing. A reusable AKS design should therefore optimize for:

- **quorum stability** for KRaft controllers
- **predictable disk performance** for broker log segments
- **retention-aware capacity planning** instead of raw-disk sizing alone
- **internal-first service exposure** with a deliberate external-access story later
- **upgrade discipline** so broker rollouts do not create avoidable under-replicated partitions

## Recommended reference architecture

```text
+-----------------------------------------------------------------------+
| AKS cluster                                                           |
|                                                                       |
|  systempool                                                           |
|   - AKS add-ons                                                       |
|                                                                       |
|  kafka user pool (3 nodes, taint: dedicated=kafka:NoSchedule)         |
|   - kafka-controller StatefulSet                                      |
|     - 3 replicas                                                      |
|     - controllerOnly=true                                             |
|     - KRaft quorum listener on 9093                                   |
|     - 32 GiB Premium SSD PVC per pod                                  |
|                                                                       |
|   - kafka-broker StatefulSet                                          |
|     - 3 replicas                                                      |
|     - client listener on 9092                                         |
|     - inter-broker listener on 9094                                   |
|     - 256 GiB Premium SSD PVC per pod                                 |
|                                                                       |
|  internal access pattern                                              |
|   - Service: kafka (ClusterIP bootstrap service)                      |
|   - Headless services for controller and broker pod DNS               |
|   - externalAccess disabled by default                                |
+-----------------------------------------------------------------------+
```

## Design decisions

| Area | Recommendation | Notes |
| --- | --- | --- |
| Cluster baseline | Use AKS AVM wrappers | Aligns Kafka with the rest of the repository |
| Node pools | `systempool` + dedicated `kafka` pool | Keeps stateful pods off the system pool while avoiding over-fragmentation |
| KRaft controllers | 3 controller-only pods | Keeps controller quorum explicit and separate from broker throughput |
| Brokers | 3 broker-only pods | Good starting point for RF=3 and `min.insync.replicas=2` |
| Auth | SASL/PLAIN on internal listeners | Keeps a starter access-control boundary without checking secrets into the repo |
| Service exposure | `ClusterIP` only by default | Safer than exposing NodePorts or public load balancers on day 1 |
| Storage | Premium Azure Disk CSI PVCs | Better match for log durability and steady throughput than ephemeral disks |
| Upgrade model | Rolling StatefulSet updates with PVC retention | Helps preserve broker identity and avoids accidental state loss |
| Recovery | Preserve `kafka-kraft` secret and retained PVCs; use secondary-cluster replication for DR | PVCs are necessary, but not a disaster-recovery plan by themselves |

## AKS-specific guidance

### 1. One dedicated user pool named `kafka`

The checked-in wrappers provision one user pool named `kafka` with **3 nodes**. That is deliberate:

- the Helm values run **3 controller-only pods** with hard anti-affinity
- the same values run **3 broker-only pods** with hard anti-affinity
- the simplest steady-state placement is **one controller and one broker per node**

The starter wrappers default the `kafka` pool to `Standard_D4s_v5`. That keeps the footprint reasonable while still leaving room for one 2 GiB controller and one 8 GiB broker on each node.

### 2. KRaft quorum is part of the platform contract

This blueprint uses KRaft rather than ZooKeeper. The Bitnami chart creates a `kafka-kraft` secret on first install, and that secret becomes part of the cluster identity alongside the controller PVCs.

Treat these as coupled state:

- keep the `kafka-kraft` secret if you keep the controller PVCs
- do not change node IDs after the cluster is initialized
- validate controller quorum health before and after upgrades

### 3. Storage and retention planning come first

Starter sizes in the checked-in values file:

| Tier | Replicas | PVC size | Purpose |
| --- | --- | --- | --- |
| Controller | 3 | 32 GiB | Metadata log and controller state |
| Broker | 3 | 256 GiB | Topic partitions, segment files, and recovery work |

With 3 brokers at 256 GiB each, the cluster starts with **768 GiB raw broker capacity**. If you reserve 20% free space for recovery and compaction, and you use a replication factor of 3, the practical single-copy retention budget is roughly **205 GiB**:

- raw capacity: `3 x 256 GiB = 768 GiB`
- usable after 20% headroom: `614 GiB`
- single-copy effective capacity at RF=3: `~205 GiB`

That is the kind of math a stateless microservice never has to surface, but Kafka does.

### 4. Listener topology matters on AKS

A stateless web service can usually hide behind one load balancer. Kafka cannot. Clients use a bootstrap address only to learn the broker-specific advertised endpoints they should talk to next.

For that reason the blueprint starts with:

- `kafka` **ClusterIP** service for in-cluster bootstrap
- chart-managed headless services for stable per-pod DNS
- `externalAccess.enabled=false` by default

If you later expose Kafka beyond the cluster, design stable per-broker addresses first. On AKS that usually means internal load balancers, private networking, or another environment-specific private routing pattern rather than a single public endpoint.

### 5. Azure Well-Architected callouts

| Pillar | Kafka-specific decision |
| --- | --- |
| Reliability | 3 controllers, 3 brokers, PDBs, and retained PVCs reduce avoidable quorum or replica loss during maintenance |
| Security | Internal-only exposure by default and no checked-in secrets; future Azure Storage integrations should use managed identity |
| Performance Efficiency | Premium SSD-backed Azure Disks and dedicated node placement fit Kafka's log-heavy I/O pattern |
| Cost Optimization | One dedicated user pool keeps the footprint simpler than multiple tiny pools while still isolating stateful data-plane pods |
| Operational Excellence | Docs include concrete rollout, quorum, topic, and PVC validation commands instead of stopping at `kubectl get pods` |

## Capacity planning starter values

| Area | Starter setting | When to change it |
| --- | --- | --- |
| Broker count | 3 | Increase before retention or partition growth creates sustained disk pressure |
| Controller count | 3 | Keep odd-sized quorum; do not scale down below 3 for this blueprint |
| Broker heap | 4 GiB | Increase when page cache is healthy but JVM pressure is the real bottleneck |
| Broker PVC | 256 GiB | Increase when retention targets or recovery windows need more headroom |
| Client access | Cluster-internal | Revisit only after you have a deliberate private endpoint design |

## Azure Storage note

Kafka broker logs stay on Azure Disk PVCs in this starter blueprint. If you later add Azure Blob or ADLS-backed integrations through Kafka Connect or another component, use **managed identity or workload identity** for auth and keep shared keys out of the design.
