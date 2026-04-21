# Apache Kafka architecture notes

Kafka on AKS should be modeled as a durable streaming platform with explicit broker placement, storage, and client access decisions.

## Initial design goals

- dedicated stateful capacity for brokers
- private or controlled listener exposure
- operator-driven lifecycle management
- monitoring for broker, partition, and storage health

