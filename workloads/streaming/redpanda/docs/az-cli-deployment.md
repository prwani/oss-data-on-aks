# Redpanda `az` CLI deployment path

Recommended automation flow:

1. deploy the AKS baseline
2. prepare namespaces and storage classes
3. install Redpanda with reproducible values
4. validate brokers, listeners, and persistence

