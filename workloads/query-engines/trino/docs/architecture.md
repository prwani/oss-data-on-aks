# Trino architecture notes

Trino should be treated as a distributed query service with clear separation between coordinator, workers, catalogs, and data access patterns.

## Initial design goals

- predictable scaling for coordinator and worker pools
- secure access to underlying data sources
- explicit catalog and secret handling
- user access patterns that match enterprise networking expectations

