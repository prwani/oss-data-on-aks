# Apache Superset CLI scripts

This folder intentionally holds instructions instead of checked-in shell scripts because the Superset bootstrap flow depends on runtime-generated secrets and real operator email addresses.

Use [`../../docs/az-cli-deployment.md`](../../docs/az-cli-deployment.md) as the primary walkthrough.

## Suggested sequence

1. deploy the AKS baseline with the Bicep or Terraform wrapper
2. connect to the cluster and apply `kubernetes/manifests/namespace.yaml` plus `kubernetes/manifests/managed-csi-premium-storageclass.yaml`
3. create `superset-postgresql-auth` and `superset-env`
4. install chart `superset/superset` version `0.15.4`
5. wait for `job/superset-init-db` to complete
6. create the first admin user with `superset fab create-admin`
7. validate the internal service, worker pods, and PVCs

Avoid turning the secret-creation commands into checked-in scripts unless your environment already has a safe secret-manager or pipeline path to inject real values.
