import json
import os
from pathlib import Path

from flask import Flask, jsonify, request
from opensearchpy import OpenSearch

INDEX_NAME = os.getenv("OPENSEARCH_INDEX", "store-products")
PRODUCTS_PATH = Path(__file__).with_name("products.json")

app = Flask(__name__)


def client() -> OpenSearch:
    return OpenSearch(
        hosts=[os.environ["OPENSEARCH_URL"]],
        http_auth=(
            os.environ.get("OPENSEARCH_USERNAME", "admin"),
            os.environ["OPENSEARCH_PASSWORD"],
        ),
        use_ssl=True,
        verify_certs=False,
        ssl_show_warn=False,
    )


def load_products() -> list[dict]:
    return json.loads(PRODUCTS_PATH.read_text(encoding="utf-8"))


@app.get("/")
def index():
    return """
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Store Search</title>
  <style>
    body { font-family: sans-serif; margin: 2rem; max-width: 900px; }
    input, select, button { font-size: 1rem; padding: .5rem; margin-right: .5rem; }
    article { border: 1px solid #ddd; border-radius: 8px; padding: 1rem; margin: 1rem 0; }
    .meta { color: #555; }
  </style>
</head>
<body>
  <h1>Store Search</h1>
  <p>This app searches a private OpenSearch service from inside AKS.</p>
  <button onclick="seed()">Seed catalog</button>
  <hr>
  <input id="q" value="running" placeholder="Search terms">
  <select id="category">
    <option value="">All categories</option>
    <option>Accessories</option>
    <option>Bags</option>
    <option>Electronics</option>
    <option>Footwear</option>
    <option>Outerwear</option>
  </select>
  <button onclick="search()">Search</button>
  <section id="results"></section>
  <script>
    async function seed() {
      const response = await fetch('/api/seed', { method: 'POST' });
      alert(JSON.stringify(await response.json()));
      search();
    }
    async function search() {
      const q = encodeURIComponent(document.getElementById('q').value);
      const category = encodeURIComponent(document.getElementById('category').value);
      const response = await fetch(`/api/search?q=${q}&category=${category}`);
      const data = await response.json();
      document.getElementById('results').innerHTML = data.results.map(product => `
        <article>
          <h2>${product.name}</h2>
          <p>${product.description}</p>
          <p class="meta">${product.brand} | ${product.category} | $${product.price} | rating ${product.rating}</p>
        </article>
      `).join('') || '<p>No results.</p>';
    }
  </script>
</body>
</html>
"""


@app.get("/healthz")
def healthz():
    return jsonify({"status": "ok"})


@app.post("/api/seed")
def seed():
    os_client = client()
    if not os_client.indices.exists(INDEX_NAME):
        os_client.indices.create(
            INDEX_NAME,
            body={
                "mappings": {
                    "properties": {
                        "name": {"type": "text"},
                        "category": {"type": "keyword"},
                        "brand": {"type": "keyword"},
                        "description": {"type": "text"},
                        "price": {"type": "float"},
                        "rating": {"type": "float"},
                        "in_stock": {"type": "boolean"},
                    }
                }
            },
        )

    for product in load_products():
        os_client.index(index=INDEX_NAME, id=product["id"], body=product, refresh=True)

    return jsonify({"indexed": len(load_products()), "index": INDEX_NAME})


@app.get("/api/search")
def search():
    q = request.args.get("q", "").strip()
    category = request.args.get("category", "").strip()

    must = []
    if q:
        must.append(
            {
                "multi_match": {
                    "query": q,
                    "fields": ["name^3", "brand^2", "description"],
                    "fuzziness": "AUTO",
                }
            }
        )
    else:
        must.append({"match_all": {}})

    filters = []
    if category:
        filters.append({"term": {"category": category}})

    response = client().search(
        index=INDEX_NAME,
        body={
            "query": {
                "bool": {
                    "must": must,
                    "filter": filters,
                }
            },
            "size": 10,
        },
    )

    return jsonify(
        {
            "query": q,
            "category": category,
            "results": [hit["_source"] for hit in response["hits"]["hits"]],
        }
    )
