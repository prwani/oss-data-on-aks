# Redpanda architecture notes

Redpanda should be treated as a stateful streaming platform with strict storage, network, and listener design requirements.

## Initial design goals

- consistent broker storage performance
- clear internal and external listener strategy
- workload isolation from general-purpose application nodes
- explicit operational guidance for upgrades and broker health

