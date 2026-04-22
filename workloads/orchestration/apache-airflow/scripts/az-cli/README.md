# Apache Airflow CLI helper area

The implementation keeps the runnable deployment flow in `../docs/az-cli-deployment.md` so the commands stay close to the architecture and Helm values.

If this folder grows later, keep scripts focused on:

- AKS credential acquisition
- runtime secret generation
- Helm install and upgrade wrappers
- validation helpers for scheduler, triggerer, and worker health
