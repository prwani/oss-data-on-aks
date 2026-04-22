# Apache Airflow operations notes

Airflow day-2 operations on AKS revolve around orchestration latency, queue health, and the stateful dependencies that sit behind the control plane.

## Daily and weekly signals

| Area | What to watch |
| --- | --- |
| Scheduler health | heartbeat age, DAG parse duration, queued task backlog |
| Triggerer health | deferred task backlog and restart count |
| Worker health | busy slots, OOM kills, retry storms, long-running task distribution |
| PostgreSQL | PVC health, migration duration, connection saturation, backup posture |
| Redis | broker availability, memory pressure, eviction behavior |
| DAG distribution | `git-sync` failures, drift between pods, repo reachability |
| Access | internal load balancer reachability and unexpected public exposure |

## AKS-specific runbooks to keep ready

- rotate Airflow crypto secrets and validate a rolling restart
- recreate the initial admin user if credentials are lost
- recover from a failed migration job before upgrading again
- move a noisy DAG queue to a dedicated worker set if a single workload dominates the pool
- validate scheduler, triggerer, and worker behavior after an AKS node image upgrade

## Scaling guidance

Prefer these steps over ad hoc scaling:

1. scale Celery workers when queue depth and task wait time are rising
2. scale scheduler replicas or scheduler CPU when DAG parsing becomes the bottleneck
3. review the `airflow` node pool size before packing more DAGs into the same cluster
4. move PostgreSQL and Redis out of the chart when they become shared platform dependencies instead of blueprint-local starter services

## Upgrade guidance

- pin the validated Airflow chart version and Airflow app version together
- let the migration job finish before marking an upgrade healthy
- snapshot or back up the metadata database before upgrades
- review Airflow 3 API server behavior and auth changes before major upgrades
- test DAG parsing, deferred tasks, and Celery worker execution after every chart change

## Security follow-up items

- rotate the fernet, API, JWT, and webserver secrets on a controlled cadence
- replace the public example DAG source with a private repo or artifact flow before production use
- integrate Azure Storage, if needed, with managed identity rather than account keys
- keep the Airflow UI internal and put corporate ingress or reverse-proxy policy in front of it if you later publish it wider inside the network

## Validation commands worth keeping handy

```bash
kubectl get pods -n airflow
kubectl get jobs -n airflow
kubectl logs deploy/airflow-scheduler -n airflow --tail=100
kubectl logs deploy/airflow-triggerer -n airflow --tail=100
kubectl describe pod -n airflow -l component=worker
kubectl get pvc -n airflow
```
