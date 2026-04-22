# Shared security guidance

Security guidance in this repository starts with one principle: the checked-in blueprint should be safe to read, clone, and adapt without exposing credentials or normalizing broad public access.

## Shared security baseline

- keep **AKS private or private-access-capable** where your landing zone supports it
- keep workload services **internal-only by default**
- prefer **managed identity or workload identity** over storage keys, shared access signatures, or checked-in client secrets
- isolate workloads with **dedicated namespaces** and, when appropriate, **dedicated user pools**
- keep **runtime secrets out of Git** even when the rest of the deployment is source controlled
- document **certificate, bootstrap-admin, and upgrade** requirements as part of the blueprint, not as tribal knowledge

## Identity and secret handling

### Azure identities

The shared AKS baseline should stay compatible with managed identities. When a workload later needs Azure Storage, Key Vault, or another Azure API:

1. prefer **workload identity** tied to a Kubernetes service account
2. grant the **minimum Azure RBAC** needed for that workload
3. record the dependency in the workload docs and Helm/manifests
4. keep shared keys and connection strings out of the checked-in values files

### Runtime secrets

Use workload deployment guides to explain how to create secrets safely at deploy time:

- `kubectl create secret ... --dry-run=client -o yaml | kubectl apply -f -`
- pipeline or secret-manager injection
- Key Vault references if the environment already standardizes on them

Do **not**:

- commit generated passwords or cert private keys
- hardcode admin bootstrap credentials in Helm values
- let `terraform.tfvars.example` or `.bicepparam` files drift into real secrets

## Network exposure model

| Concern | Shared recommendation | Typical workload follow-up |
| --- | --- | --- |
| AKS API access | keep it private or restricted to approved networks when possible | explain any exception in the workload docs |
| Workload services | start with `ClusterIP` or a private-only path | document internal load balancer, private ingress, or broker-specific listeners only when needed |
| Admin access | prefer port-forward, bastion, or private connectivity during validation | describe the supported operator path in `docs/portal-deployment.md` and `docs/az-cli-deployment.md` |
| East-west traffic | keep namespace boundaries explicit | add policies or service-to-service auth if the workload spans components |

Public exposure is a workload decision, not a template default. If a workload must expose an endpoint, explain:

- why private access is not enough
- how TLS and certificate rotation are handled
- how clients discover stable endpoints
- what RBAC, firewall, or ingress limits protect that endpoint

## Namespace and node-pool isolation

The expanded blueprints in this repo consistently use namespace and node-pool boundaries as part of the security story:

- namespace manifests create a clean scope for RBAC, secrets, and Pod Security labels
- dedicated user pools reduce accidental co-scheduling with unrelated workloads
- taints and tolerations make workload placement intentional
- Pod Security labels should be explicit when a chart requires privileged behavior

Keep those settings documented in the workload `README.md`, `docs/architecture.md`, and chart values.

## Checklist for workload authors

Every workload should answer these before it is considered ready:

1. **How is the first admin or operator account created?**
2. **Where do passwords, tokens, or certificates come from at deployment time?**
3. **Does the workload stay internal by default?**
4. **Which Azure permissions are required, and can they use workload identity?**
5. **What namespace, taints, or Pod Security labels are required?**
6. **What post-install hardening settings should operators review?**

## Workload-specific follow-up

Each workload folder should refine the shared guidance with:

- admin bootstrap flow
- certificate strategy
- internal versus external endpoint design
- backup and restore credential handling
- chart or operator hardening settings
- upgrade steps that avoid security regressions
