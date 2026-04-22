# `<workload>` architecture notes

Replace the placeholders in this file and explain why this workload needs a specific AKS design instead of a generic stateless deployment.

## Why this workload needs a different AKS design

Describe the workload behavior that drives platform choices, for example:

- quorum members or control-plane pods
- durable state or large spill paths
- node-local CPU, memory, or disk requirements
- listener or service-exposure constraints
- operator, chart-hook, or bootstrap dependencies

## Recommended reference architecture

```text
+------------------------------------------------------------------+
| AKS cluster                                                      |
|                                                                  |
|  systempool                                                      |
|   - AKS add-ons and shared services                              |
|                                                                  |
|  <workload-pool>                                                 |
|   - dedicated user-pool nodes                                    |
|   - workload control plane and/or data plane                     |
|                                                                  |
|  namespace-scoped assets                                         |
|   - secrets, PVCs, jobs, operators, or helper manifests          |
|                                                                  |
|  service exposure                                                |
|   - internal-only by default unless documented otherwise         |
+------------------------------------------------------------------+
```

## Design decisions

| Area | Recommendation | Notes to fill in |
| --- | --- | --- |
| Cluster baseline | use the shared AKS AVM wrappers | explain only the workload-specific additions |
| Node pools | keep `systempool` plus one or more dedicated user pools | document labels, taints, and sizing |
| Service exposure | stay `ClusterIP` or private-only by default | justify any public or broker-specific endpoint design |
| Storage | document durable vs ephemeral paths | capture PVC sizes, classes, or scratch volumes |
| Identity | use managed identity or workload identity | call out Azure API, Blob, ADLS, or Key Vault access |
| Upgrades | define health gates before rollouts | mention hooks, quorum, migrations, or drain order |

## AKS-specific guidance

### 1. Dedicated node-pool intent

State which pods belong on the dedicated pool, why they should not share the system pool, and how many nodes are required for the starter layout.

### 2. Storage and state model

Explain what persists, what is ephemeral, and what storage class or disk profile the blueprint assumes.

### 3. Networking and service exposure

Describe the service type, listener model, and any private ingress or internal load balancer expectations.

### 4. Identity, secrets, and Azure integrations

Call out runtime-generated secrets, bootstrap admin flow, and any Azure integrations that should use workload identity.

### 5. Observability and runbooks

List the signals that operators must validate after install, upgrade, or node maintenance.

## Capacity planning starter values

Add a table here for starter sizing, for example:

| Area | Starter value | Why |
| --- | --- | --- |
| Dedicated pool | `<count> x <vm-size>` | explain placement intent |
| Replicas | `<n>` | explain quorum, HA, or worker parallelism |
| Durable storage | `<size/class>` | explain retention or recovery assumptions |
| Access model | internal only / private-only | explain the starter security posture |

## Azure Storage note

If the workload writes to Azure Blob, ADLS, or backup storage, document the intended managed-identity or workload-identity path and keep shared keys out of the design.
