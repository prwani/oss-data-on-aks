# Shared observability guidance

Each workload blueprint should plug into a common operational model.

## Minimum expectations

- cluster health visibility
- node pool and pod scheduling visibility
- workload-specific metrics and logs
- alerting for storage pressure, restarts, and replica health
- backup and restore status for stateful platforms

## Suggested rollout pattern

1. Start with platform telemetry for AKS.
2. Add workload-native metrics and dashboards.
3. Capture runbooks inside the workload folder and blog artifacts.

