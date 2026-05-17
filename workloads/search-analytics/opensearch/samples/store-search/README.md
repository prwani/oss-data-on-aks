# Store search sample

This sample demonstrates the enterprise pattern used in the secure OpenSearch-on-AKS guidance:

```text
browser or operator test
  -> store-search app
    -> private OpenSearch ClusterIP service
```

The app indexes a small product catalog and exposes a basic search API. OpenSearch stays private inside the AKS cluster.

## Build and publish the image

Use an Azure Container Registry that your AKS cluster can pull from:

```bash
export ACR_NAME=<acr-name>
export STORE_SEARCH_IMAGE="${ACR_NAME}.azurecr.io/store-search:0.1.0"

az acr build \
  --registry "$ACR_NAME" \
  --image store-search:0.1.0 \
  workloads/search-analytics/opensearch/samples/store-search
```

Update `kubernetes/store-search.yaml` so the deployment uses your `$STORE_SEARCH_IMAGE`.

## Deploy the sample

Create the namespace and app secret with the same OpenSearch admin password used during bootstrap:

```bash
export OPENSEARCH_ADMIN_PASSWORD='<strong-admin-password>'

kubectl create namespace store-search --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic store-search-opensearch \
  --namespace store-search \
  --from-literal=username='admin' \
  --from-literal=password="$OPENSEARCH_ADMIN_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -
```

Use the same password value that initialized OpenSearch. Reapplying the Kubernetes Secret with a different value does not rotate the internal `admin` password after the security index exists.

Apply the workload manifest:

```bash
kubectl apply -f workloads/search-analytics/opensearch/samples/store-search/kubernetes/store-search.yaml
kubectl rollout status deploy/store-search -n store-search --timeout=300s
```

## Test the app

Use port-forward through your existing AKS API connection, including an Azure Bastion tunnel for private clusters:

```bash
export GODEBUG=http2client=0
kubectl port-forward svc/store-search 8080:80 -n store-search
```

Seed the demo catalog:

```bash
curl -s -XPOST http://127.0.0.1:8080/api/seed
```

Run a search:

```bash
curl -s "http://127.0.0.1:8080/api/search?q=running&category=Footwear"
```

Then open `http://127.0.0.1:8080` in a browser.
