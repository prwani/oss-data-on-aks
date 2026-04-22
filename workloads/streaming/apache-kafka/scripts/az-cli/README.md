# Apache Kafka `az` CLI helpers

This folder is reserved for repeatable helper scripts that sit beside the workload docs, not in place of them.

## Intended scope

Use this folder for scripts that automate the exact flows documented elsewhere in the blueprint, such as:

- running the Bicep or Terraform wrappers with repo-standard defaults
- generating the `kafka-auth` secret values and applying the Kubernetes secret idempotently
- creating a short-lived Kafka client pod and loading `client.properties` for topic validation
- collecting rollout, PVC, and KRaft quorum diagnostics after install or upgrade

The authoritative steps remain in `docs/az-cli-deployment.md` and `docs/operations.md`. Add scripts here only when the team wants an idempotent wrapper for those concrete paths.
