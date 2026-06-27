# Getting started with Trino on AKS with AKS AVM, Iceberg, and Superset

**Publication target:** Microsoft TechCommunity > Azure > Linux and Open Source Blog

## Summary

TODO: Introduce the goal of the post: deploy an Azure baseline for Trino on AKS, then use Helm and Kubernetes-native steps to install Trino, Apache Polaris as the Iceberg REST catalog, materialize TPCDS into Iceberg on ADLS Gen2, and connect Apache Superset as a BI experience.

## What we are building

TODO: Explain that the "Deploy to Azure" experience provisions the Azure baseline only. The Trino, Polaris, TPCDS, and Superset steps remain explicit in the blog so readers can see and learn the Kubernetes and Helm operations.

The target flow for the blog is:

1. Deploy the Azure baseline with AKS AVM.
2. Connect to the AKS cluster.
3. Install Apache Polaris with PostgreSQL-backed metadata.
4. Install Trino with the TPCDS source catalog and Iceberg REST catalog.
5. Materialize selected TPCDS SF1 tables into Iceberg on ADLS Gen2.
6. Install Apache Superset and connect it to Trino.
7. Validate with SQL, ADLS file listings, and a Superset query.

## Architecture

TODO: Add the final architecture narrative and diagram.

![Trino on AKS architecture](../assets/trino-on-aks-architecture.svg)

## Prerequisites

TODO: Add prerequisites for Azure CLI, kubectl, Helm, permissions, AKS quota, and region selection.

## Step 1: Deploy the Azure baseline

TODO: Add the baseline "Deploy to Azure" button once the portal template exists.

The baseline should provision:

- ADLS Gen2 storage with hierarchical namespace enabled
- a user-assigned managed identity for lakehouse access
- workload identity federation for Trino and Polaris service accounts
- AKS through the AKS AVM wrapper
- dedicated node pools for `trino`, `catalog`, and optionally `superset`
- Azure Database for PostgreSQL Flexible Server for Polaris metadata

## Step 2: Connect to AKS

TODO: Add the final command sequence for `az aks get-credentials`, namespace creation, and local tooling expectations.

## Step 3: Install Apache Polaris as the Iceberg REST catalog

TODO: Add the Polaris Helm install, PostgreSQL secret creation, root realm bootstrap, catalog creation, Trino principal creation, and role grants. Keep secrets out of source control and show placeholders only.

## Step 4: Install Trino

TODO: Add the Trino Helm install and the Iceberg/ADLS override flow.

## Step 5: Validate the deployment

At minimum, validate the node pools, pod health, service shape, Trino catalogs, Polaris catalog access, and Superset rollout.

```bash
kubectl get nodes -L agentpool

kubectl get pods -n iceberg-catalog
kubectl get pods -n trino
kubectl get pods -n superset

kubectl get svc -n trino
kubectl get svc -n superset
```

For the expected AKS shape, you should see separate node pools for the query engine, catalog service, and BI layer:

```text
AGENTPOOL
systempool
trino
catalog
superset
```

The Trino coordinator and workers should be running:

```bash
kubectl get pods -n trino
```

Expected shape:

```text
trino-coordinator-...   1/1   Running
trino-worker-...        1/1   Running
trino-worker-...        1/1   Running
trino-worker-...        1/1   Running
```

Validate the Trino catalogs:

```bash
kubectl exec deploy/trino-coordinator -n trino -- \
  trino --execute "SHOW CATALOGS"
```

Expected output includes:

```text
"iceberg"
"system"
"tpcds"
```

Validate the Iceberg REST catalog path:

```bash
kubectl exec deploy/trino-coordinator -n trino -- \
  trino --execute "SHOW SCHEMAS FROM iceberg"
```

After the TPCDS materialization step, the output should include:

```text
"tpcds_sf1"
```

Validate the persisted row counts:

```bash
kubectl exec deploy/trino-coordinator -n trino -- trino --execute "
SELECT 'customer' AS table_name, count(*) AS rows FROM iceberg.tpcds_sf1.customer
UNION ALL SELECT 'date_dim', count(*) FROM iceberg.tpcds_sf1.date_dim
UNION ALL SELECT 'item', count(*) FROM iceberg.tpcds_sf1.item
UNION ALL SELECT 'store_sales', count(*) FROM iceberg.tpcds_sf1.store_sales
ORDER BY table_name"
```

For TPCDS scale factor 1, the starter tables should return:

```text
"customer","100000"
"date_dim","73049"
"item","18000"
"store_sales","2880404"
```

Use ADLS Gen2 listing with Microsoft Entra authentication to confirm that Iceberg metadata and Parquet data files exist without using storage keys:

```bash
az storage fs file list \
  --account-name <storage-account-name> \
  --file-system lakehouse \
  --path iceberg/warehouse/tpcds_sf1 \
  --auth-mode login \
  -o table
```

You should see table directories with `data` and `metadata` children, including `.parquet`, `.metadata.json`, `.avro`, and `.stats` files.

## Step 6: Exercise Trino SQL and API access

The TPCDS connector proves that Trino can generate benchmark rows, but the more important validation is querying persisted Iceberg data in ADLS Gen2.

First, run a small query against the generated source catalog:

```bash
kubectl exec deploy/trino-coordinator -n trino -- \
  trino --execute "SELECT count(*) AS customers FROM tpcds.tiny.customer"
```

Then query the persisted Iceberg tables:

```bash
kubectl exec deploy/trino-coordinator -n trino -- trino --execute "
SELECT i.i_category, count(*) AS rows
FROM iceberg.tpcds_sf1.store_sales ss
JOIN iceberg.tpcds_sf1.item i
  ON ss.ss_item_sk = i.i_item_sk
GROUP BY i.i_category
ORDER BY rows DESC
LIMIT 5"
```

The result should look similar to:

```text
"Music                                             ","299529"
"Shoes                                             ","294887"
"Electronics                                       ","288475"
"Women                                             ","286442"
"Sports                                            ","286124"
```

For API validation without exposing Trino publicly, use port-forward:

```bash
kubectl port-forward svc/trino 8080:8080 -n trino
curl http://127.0.0.1:8080/v1/info
```

Keep the Trino service private for normal use. If multiple users need access from a private network, prefer an internal Azure Load Balancer or private ingress pattern rather than exposing the coordinator publicly.

## Step 7: Superset quickstart

Apache Superset is optional for the Trino workload, but it is a useful way to prove that the Iceberg tables are consumable from a BI tool. In this starter flow, Superset runs in AKS with chart-managed PostgreSQL and Redis. For production-scale cache and Celery broker requirements, use Azure Managed Redis or another externally operated Redis-compatible service.

Install Superset from the repo assets:

```bash
kubectl apply -f workloads/bi/apache-superset/kubernetes/manifests/namespace.yaml

kubectl create secret generic superset-postgresql-auth -n superset \
  --from-literal=password="$SUPERSET_POSTGRES_PASSWORD"

kubectl create secret generic superset-env -n superset \
  --from-literal=DB_HOST="superset-postgresql" \
  --from-literal=DB_PORT="5432" \
  --from-literal=DB_USER="superset" \
  --from-literal=DB_PASS="$SUPERSET_POSTGRES_PASSWORD" \
  --from-literal=DB_NAME="superset" \
  --from-literal=REDIS_HOST="superset-redis-headless" \
  --from-literal=REDIS_PORT="6379" \
  --from-literal=REDIS_PROTO="redis" \
  --from-literal=REDIS_DB="1" \
  --from-literal=REDIS_CELERY_DB="0" \
  --from-literal=SUPERSET_SECRET_KEY="$SUPERSET_SECRET_KEY"

helm repo add superset https://apache.github.io/superset
helm repo update

helm upgrade --install superset superset/superset \
  --version 0.15.5 \
  --namespace superset \
  --values workloads/bi/apache-superset/kubernetes/helm/superset-values.yaml
```

Wait for the database migration job and deployments:

```bash
kubectl wait --for=condition=complete job/superset-init-db -n superset --timeout=25m
kubectl wait --for=condition=available deployment/superset -n superset --timeout=10m
kubectl wait --for=condition=available deployment/superset-worker -n superset --timeout=10m
```

Create the first administrator:

```bash
kubectl exec -n superset deploy/superset -- \
  superset fab create-admin \
    --username admin \
    --firstname Platform \
    --lastname Admin \
    --email "$SUPERSET_ADMIN_EMAIL" \
    --password "$SUPERSET_ADMIN_PASSWORD"
```

Add the Trino datasource:

```bash
kubectl exec -n superset deploy/superset -- \
  superset set-database-uri \
    -d trino_iceberg_tpcds \
    -u trino://superset@trino.trino.svc.cluster.local:8080/iceberg/tpcds_sf1
```

Validate the same Trino connection from inside the Superset pod:

```bash
kubectl exec -n superset deploy/superset -- python -c "
from sqlalchemy import create_engine, text
engine = create_engine('trino://superset@trino.trino.svc.cluster.local:8080/iceberg/tpcds_sf1')
with engine.connect() as conn:
    print(conn.execute(text('SELECT count(*) FROM iceberg.tpcds_sf1.customer')).fetchall())
"
```

Expected output:

```text
[(100000,)]
```

For a quick UI check without public exposure:

```bash
kubectl port-forward svc/superset 8088:8088 -n superset
```

Open `http://127.0.0.1:8088`, sign in with the admin user, open SQL Lab, select the `trino_iceberg_tpcds` database, and run:

```sql
SELECT i_category, count(*) AS rows
FROM item i
JOIN store_sales ss
  ON ss.ss_item_sk = i.i_item_sk
GROUP BY i_category
ORDER BY rows DESC
LIMIT 5;
```

Those examples are intentionally small, but they prove the full path: Trino is running on AKS, Polaris is serving an Iceberg REST catalog, TPCDS has been persisted as Iceberg/Parquet data in ADLS Gen2, and Superset can query the data through Trino.

## Why this starting pattern works

TODO: Explain why the baseline-plus-explicit-Helm pattern is better than a hidden all-in-one installer.

## Production considerations

TODO: Expand guidance for sizing, autoscaling, private access, observability, Polaris hardening, PostgreSQL backup, Superset cache strategy, and cost control.

## What comes next

TODO: Point readers to the repo docs for deeper deployment options, operations guidance, and cleanup.
