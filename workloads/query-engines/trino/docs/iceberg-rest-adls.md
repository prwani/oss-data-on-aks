# Iceberg REST catalog on ADLS Gen2

This blueprint uses ADLS Gen2 as the durable lakehouse store and an Iceberg REST catalog as the production-style table catalog for Trino.

## Storage model

| Layer | Role |
| --- | --- |
| ADLS Gen2 | Stores Iceberg metadata files and table data files |
| Iceberg | Defines tables, snapshots, schema evolution, and manifests |
| Parquet | Default physical data file format |
| Iceberg REST catalog | Coordinates table metadata operations through a REST API |
| Trino | Reads and writes Iceberg tables through the REST catalog |

The Trino `tpcds` connector is only a deterministic source generator. Data becomes durable only after CTAS writes it into `iceberg.*` tables backed by ADLS Gen2.

## Identity and access

The infrastructure wrapper provisions:

- ADLS Gen2 storage account with hierarchical namespace enabled
- `lakehouse` file system/container
- user-assigned managed identity for lakehouse access
- `Storage Blob Data Contributor` on the storage account
- AKS OIDC issuer and workload identity
- federated credentials for:
  - `system:serviceaccount:trino:trino`
  - `system:serviceaccount:iceberg-catalog:polaris`

Do not enable shared-key or account-key access for this path.

## Trino catalog properties

Use an environment-specific Helm override based on `trino-iceberg-adls-values.example.yaml`:

```properties
connector.name=iceberg
iceberg.catalog.type=rest
iceberg.rest-catalog.uri=http://polaris.iceberg-catalog.svc.cluster.local:8181/api/catalog
iceberg.rest-catalog.warehouse=lakehouse
iceberg.rest-catalog.security=OAUTH2
iceberg.rest-catalog.oauth2.credential=<polaris-client-id>:<polaris-client-secret>
iceberg.rest-catalog.oauth2.scope=PRINCIPAL_ROLE:ALL
iceberg.rest-catalog.oauth2.server-uri=http://polaris.iceberg-catalog.svc.cluster.local:8181/api/catalog/v1/oauth/tokens
iceberg.rest-catalog.vended-credentials-enabled=true
iceberg.file-format=PARQUET
fs.native-azure.enabled=true
azure.auth-type=DEFAULT
```

`azure.auth-type=DEFAULT` lets Trino use the Azure identity environment injected by Azure Workload Identity.

## Production catalog persistence

Use relational JDBC persistence for Apache Polaris and back it with Azure Database for PostgreSQL Flexible Server. The checked-in Kubernetes values expect a secret named `polaris-postgresql` with:

- `username`
- `password`
- `jdbcUrl`

Keep that secret out of source control.
