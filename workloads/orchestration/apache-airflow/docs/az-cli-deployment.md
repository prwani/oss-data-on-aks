# Apache Airflow `az` CLI deployment path

Recommended automation flow:

1. deploy the shared AKS baseline
2. provision required dependencies and secrets
3. install Airflow components
4. validate scheduler, webserver, and worker behavior

