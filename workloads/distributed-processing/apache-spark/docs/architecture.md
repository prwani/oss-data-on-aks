# Apache Spark architecture notes

Spark on AKS should emphasize job execution patterns, storage access, and multi-tenant cluster behavior.

## Initial design goals

- clear separation of platform baseline and Spark runtime concerns
- secure access to external storage and catalogs
- worker elasticity and queueing expectations
- support for lakehouse-oriented extensions later

