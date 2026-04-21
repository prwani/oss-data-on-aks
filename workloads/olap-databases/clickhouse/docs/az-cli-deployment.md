# ClickHouse `az` CLI deployment path

Recommended automation flow:

1. deploy the shared AKS baseline
2. prepare namespaces and storage classes
3. install ClickHouse components
4. validate readiness, storage, and query access

