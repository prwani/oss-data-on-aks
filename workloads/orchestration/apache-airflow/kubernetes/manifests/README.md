# Apache Airflow manifest overlays

This folder intentionally stays small.

- `namespace.yaml` creates the workload namespace used by the Helm release

The rest of the runtime material is created during deployment instead of being committed:

- Airflow crypto secrets (`fernet`, API, JWT, and webserver secrets)
- PostgreSQL and Redis credentials
- SQLAlchemy and broker connection secrets

Keeping those values out of source control avoids fake passwords and keeps the starter compatible with secret managers or sealed-secret workflows later.
