# Apache Flink Kubernetes assets

This folder keeps the Kubernetes assets organized into Helm values and raw manifests.

## Helm

The `helm/` subfolder holds the checked-in values for the Flink Kubernetes Operator Helm chart. The operator manages `FlinkDeployment` custom resources and handles job lifecycle, autoscaling, and upgrades.

## Manifests

The `manifests/` subfolder keeps workload-namespace objects and sample FlinkDeployment resources that the operator reconciles.

## Relationship between operator and workload

The Flink operator runs in the `flink-operator` namespace on the system pool. It watches the `flink` namespace for `FlinkDeployment` resources and manages JobManager and TaskManager pods.

The workload manifests (namespace, RBAC, FlinkDeployment) are managed separately from the Helm chart so that RBAC, placement, and autoscaling decisions stay explicit in source control.
