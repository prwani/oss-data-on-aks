# Apache Superset manifest overlays

This folder intentionally stays small.

- `namespace.yaml` creates the workload namespace used by the Helm release

The rest of the runtime material is created during deployment instead of being committed:

- `superset-postgresql-auth` for the chart-managed PostgreSQL password
- `superset-env` for database coordinates, Redis coordinates, and `SUPERSET_SECRET_KEY`
- optional future secrets for SSO, SMTP, or datasource credentials

Keeping those values out of source control avoids fake passwords and leaves room for secret managers, External Secrets Operator, or workload identity-based Azure integrations later.
