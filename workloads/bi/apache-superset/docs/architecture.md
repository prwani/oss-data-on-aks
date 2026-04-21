# Apache Superset architecture notes

Superset on AKS should be treated as an analytics application tier with explicit dependencies on identity, metadata, and query backends.

## Initial design goals

- secure UI access and secret handling
- clear integration story with Trino and other engines
- repeatable metadata and dashboard persistence
- operational guidance for upgrades and extensions

