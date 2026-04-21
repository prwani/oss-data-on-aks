# Apache Airflow architecture notes

Airflow on AKS should be treated as an orchestrator platform with clear separation between stateless control-plane components and its state dependencies.

## Initial design goals

- explicit executor choice and scaling model
- secure handling of metadata database and secrets
- predictable DAG delivery and worker lifecycle
- operational guidance for upgrades and scheduler health

