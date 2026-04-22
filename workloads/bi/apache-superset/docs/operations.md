# Apache Superset operations notes

Superset day-2 operations on AKS revolve around UI responsiveness, Celery queue health, and the stateful metadata services that sit behind the control plane.

## Daily and weekly signals

| Area | What to watch |
| --- | --- |
| Web tier | pod restarts, `/health` readiness, gunicorn timeouts, and 5xx rates |
| Celery workers | queued async queries, long-running task backlog, OOM kills, and worker restart loops |
| Init job | `superset-init-db` completion time and failed hook reruns |
| PostgreSQL | PVC health, backup posture, connection saturation, and schema migration duration |
| Redis | memory pressure, persistence health, eviction behavior, and restart count |
| Access | internal load balancer reachability and any unexpected public exposure |
| Data-source connectivity | failing SQL Lab test queries, DNS issues, and rotated datasource credentials |

## AKS-specific runbooks to keep ready

- rerun or clean up a failed `superset-init-db` job before retrying the next upgrade
- create or reset the initial admin user without editing chart values
- scale `superset-worker` when SQL Lab async backlog starts climbing
- validate PostgreSQL and Redis PVC health after AKS node image upgrades or drain events
- back up and restore the metadata database before major chart or app-version jumps

## Scaling guidance

Prefer these steps over ad hoc scaling:

1. scale `superset-worker` when async query backlog and task wait time are the main problem
2. scale the `superset` web deployment or web CPU when UI and API latency are the main problem
3. review the `superset` node pool size before adding more web and worker replicas to the same cluster
4. move PostgreSQL and Redis out of the chart when they become shared platform dependencies instead of blueprint-local starter services

## Upgrade guidance

- pin the validated Superset chart version and app version together
- back up the metadata database before upgrades
- watch `superset-init-db` to completion before marking an upgrade healthy
- retest saved dashboards, SQL Lab async queries, and data-source connections after every chart change
- recheck the internal load balancer annotation and service account settings after major platform updates

## Security follow-up items

- keep the Superset UI internal and put corporate ingress or reverse-proxy policy in front of it if you later publish it wider inside the network
- rotate `SUPERSET_SECRET_KEY` only with a metadata backup and a maintenance window because it protects encrypted metadata values
- rotate metadata database credentials by recreating `superset-postgresql-auth` and `superset-env` in a controlled rollout
- keep datasource passwords, OAuth secrets, and SMTP secrets out of Git and out of inline Helm values
- use managed identity for any Azure Storage integration instead of shared keys or account-key secrets

## Validation commands worth keeping handy

```bash
kubectl get pods -n superset
kubectl get jobs -n superset
kubectl get pvc -n superset
kubectl logs job/superset-init-db -n superset --tail=100
kubectl logs deploy/superset -n superset --tail=100
kubectl logs deploy/superset-worker -n superset --tail=100
kubectl describe svc superset -n superset
kubectl port-forward svc/superset 8088:8088 -n superset
```

This starter leaves Celery beat and Flower disabled. If you turn on scheduled reports or queue monitoring later, add those components to the validation and runbook set before calling the platform production-ready.
