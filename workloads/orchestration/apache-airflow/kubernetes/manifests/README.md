# Apache Airflow manifest overlays

This folder intentionally stays small.

- `managed-csi-premium-storageclass.yaml` creates the cluster-scoped Premium SSD storage class expected by the checked-in Helm values
- `namespace.yaml` creates the workload namespace used by the Helm release

Apply both manifests before the Helm release so the `airflow-postgresql` and `airflow-redis` PVCs can bind consistently on AKS.

The rest of the runtime material is created during deployment instead of being committed:

- Airflow crypto secrets (`fernet`, API, JWT, and webserver secrets)
- PostgreSQL and Redis credentials
- SQLAlchemy and broker connection secrets

Keeping those values out of source control avoids fake passwords and keeps the starter compatible with secret managers or sealed-secret workflows later.
