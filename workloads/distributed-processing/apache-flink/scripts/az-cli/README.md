# Apache Flink CLI helper area

The runnable deployment flow lives in `../docs/az-cli-deployment.md` so the operator install, namespace setup, and FlinkDeployment submission steps stay next to the architecture and operations guidance.

If this folder grows later, keep scripts focused on:

- AKS credential acquisition
- Helm operator install and upgrade wrappers
- FlinkDeployment submission and cleanup helpers
- AKS cluster autoscaler enablement
- validation helpers for JobManager and TaskManager placement
