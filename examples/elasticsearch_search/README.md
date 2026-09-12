# Elasticsearch Search Example

A small full-text search API using
[`vania_elasticsearch`](../../packages/vania_elasticsearch) with the
[Vania](../../packages/core) framework. It indexes `Article` documents and
searches them.

## How it works

- [lib/models/article.dart](lib/models/article.dart) — a `Model` with the
  `Searchable` mixin. It indexes into the `articles` index (the table name)
  using `toJson()` as the body.
- [article_controller.dart](lib/features/search/article_controller.dart) —
  `store` indexes a document (`article.searchable()`); `search` runs a
  multi-match query (`Article().search(q, fields: [...])`).
- [config/app.dart](lib/config/app.dart) — `ElasticsearchServiceProvider`
  points the client at `ELASTICSEARCH_HOST` (default `http://localhost:9200`).

## Endpoints

| Method | Path                          | Description              |
|--------|-------------------------------|--------------------------|
| POST   | `/api/articles`               | Index an article         |
| GET    | `/api/articles/search?q=...`  | Full-text search         |

## Running

Needs a reachable Elasticsearch cluster:

```bash
docker run -p 9200:9200 -e discovery.type=single-node \
  -e xpack.security.enabled=false docker.elastic.co/elasticsearch/elasticsearch:8.13.0

dart pub get
dart run bin/server.dart
```

```bash
curl -X POST localhost:8000/api/articles \
  -H 'Content-Type: application/json' \
  -d '{"id":1,"title":"Vania","body":"A Dart backend framework"}'

curl 'localhost:8000/api/articles/search?q=dart'
```

## Tests

The tests inject a fake `ElasticsearchTransport`, so they verify the indexing
and search requests **without a running cluster**:

```bash
dart test
```
