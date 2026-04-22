# Apache Spark CLI helper area

The runnable deployment flow lives in `../docs/az-cli-deployment.md` so the operator install, namespace setup, and SparkApplication submission steps stay next to the architecture and operations guidance.

If this folder grows later, keep scripts focused on:

- AKS credential acquisition
- Helm operator install and upgrade wrappers
- SparkApplication submission and cleanup helpers
- validation helpers for driver and executor placement
