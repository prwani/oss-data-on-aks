# Redpanda Helm assets

This folder contains the pinned Helm values for the starter Redpanda cluster on AKS.

## Install sequence

```bash
export CERT_MANAGER_VERSION=v1.17.2
export CHART_VERSION=26.1.1

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml

kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-webhook -n cert-manager

kubectl apply -f workloads/streaming/redpanda/kubernetes/manifests/managed-csi-premium-storageclass.yaml
kubectl apply -f workloads/streaming/redpanda/kubernetes/manifests/namespace.yaml

helm repo add redpanda https://charts.redpanda.com
helm repo update

helm upgrade --install redpanda redpanda/redpanda \
  --version "$CHART_VERSION" \
  --namespace redpanda \
  --values workloads/streaming/redpanda/kubernetes/helm/redpanda-values.yaml
```

## Uninstall sequence

```bash
helm uninstall redpanda -n redpanda
kubectl delete pvc --all -n redpanda --wait=false
kubectl delete namespace redpanda --wait=true --timeout=600s
```

## Notes

- the values assume a dedicated `rpbroker` pool with three nodes and the taint `dedicated=redpanda-broker:NoSchedule`
- chart `26.1.1` keeps TLS enabled by default and requires cert-manager CRDs before the Helm install
- the storage class manifest matches the AKS built-in `managed-csi-premium` definition, so applying it stays compatible with new AKS clusters
- uninstall the Helm release before deleting a Terraform-managed AKS cluster or broker pool so node draining does not fail on running brokers
- `external.enabled: false` keeps admin, Kafka, Schema Registry, and HTTP listener exposure internal only
- `tuning.tune_aio_events: true` means the `redpanda` namespace must allow a privileged container
- SASL is disabled in the checked-in values so the repo does not ship bootstrap credentials; enable it later through an external secret workflow
- tiered storage is disabled in the checked-in values; when you enable Azure Blob offload, use managed identity and never shared keys
