# `<workload>` Helm assets

Use this folder for the pinned chart values and chart-specific notes that support the workload blueprint.

## Release contract

Fill in these details once the real workload is chosen:

- chart repository: `<repo-name>/<chart-name>`
- chart version: `<pin-me>`
- runtime or app version: `<pin-me if different>`
- release name: `<release-name>`
- namespace: `<namespace>`

## Install sequence

Keep the install sequence aligned with the checked-in values file:

```bash
kubectl apply -f workloads/<category>/<workload>/kubernetes/manifests/namespace.yaml

helm repo add <chart-repo-name> <chart-repo-url>
helm repo update

helm upgrade --install <release-name> <chart-repo-name>/<chart-name> \
  --version <chart-version> \
  --namespace <namespace> \
  --values workloads/<category>/<workload>/kubernetes/helm/workload-values.yaml
```

Add any secret-generation or operator bootstrap prerequisites above this block once the workload is defined.

## Notes

Record the decisions operators must remember, such as:

- dedicated node-pool selectors and tolerations
- internal-only service exposure by default
- expected secrets or existing secret references
- storage classes, PVC sizes, or scratch-volume settings
- any environment-specific override pattern such as an internal load balancer overlay
