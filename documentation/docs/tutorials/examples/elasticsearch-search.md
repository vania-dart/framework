---
sidebar_position: 10
---

# Walkthrough: Elasticsearch Search

**Sample:** `examples/elasticsearch_search` · **Needs:** Elasticsearch

A small full-text search API. It indexes `Article` documents into Elasticsearch and searches them by keyword. The nice part is how little code it takes: a model gains search powers by mixing in `Searchable`, and the controller is two short methods.

See the [Elasticsearch](../../packages/elasticsearch.md) package page for the full client and query API.

## Run it

Start Elasticsearch, then the app:

```bash
docker run -p 9200:9200 -e discovery.type=single-node \
  -e xpack.security.enabled=false \
  docker.elastic.co/elasticsearch/elasticsearch:8.13.0

cd examples/elasticsearch_search
dart pub get
dart run bin/server.dart
```

```bash
curl -X POST localhost:8000/api/articles \
  -H 'Content-Type: application/json' \
  -d '{"id":1,"title":"Vania","body":"A Dart backend framework"}'

curl 'localhost:8000/api/articles/search?q=dart'
```

## Pointing the client at the cluster

```dart
// lib/config/app.dart
'providers': <ServiceProvider>[
  ElasticsearchServiceProvider(
    config: ElasticsearchConfig(
      hosts: [Uri.parse(env('ELASTICSEARCH_HOST', 'http://localhost:9200'))],
      defaultIndex: 'articles',
    ),
  ),
  RouteServiceProvider(),
],
```

`hosts` is the cluster address; `defaultIndex` is where documents go when a model doesn't say otherwise.

## A searchable model

This is the whole model. Extending `Model` and mixing in `Searchable` is what makes it indexable:

```dart
// lib/models/article.dart
class Article extends Model with Searchable {
  Article({int? id, String? title, String? body}) {
    tableName = 'articles';                 // the table name doubles as the index
    if (id != null) attributes['id'] = id;
    if (title != null) attributes['title'] = title;
    if (body != null) attributes['body'] = body;
  }
}
```

By default, `Searchable` uses the model's table name (`articles`) as the Elasticsearch index, and the model's `toJson()` as the document body. So indexing an article means "take this model's fields and push them into the `articles` index." No separate mapping code.

## Indexing a document

```dart
// lib/features/search/article_controller.dart
Future<Response> store(Request req) async {
  await req.validate({
    'id': 'required|numeric',
    'title': 'required|string',
    'body': 'required|string',
  });

  final article = Article(
    id: int.parse(req.input('id').toString()),
    title: req.input('title') as String,
    body: req.input('body') as String,
  );
  await article.searchable(refresh: 'wait_for');

  return Response.json({'indexed': article.searchableId()}, 201);
}
```

`article.searchable()` indexes the document. The `refresh: 'wait_for'` argument is the detail that trips people up: Elasticsearch is **near-real-time**, so a freshly indexed document is not searchable for a moment by default. `wait_for` tells the write to wait until the document is visible before returning — which is what makes the example's index-then-search flow deterministic. In production you usually skip this for throughput and accept the small delay.

## Searching

```dart
Future<Response> search(Request req) async {
  final query = req.input('q')?.toString() ?? '';
  final result = await Article().search(query, fields: ['title', 'body']);

  return Response.json({'total': result.total, 'hits': result.hits});
}
```

`Article().search(query, fields: ['title', 'body'])` runs a **multi-match** query — it looks for the term across both the `title` and `body` fields and ranks results by relevance. The result exposes `total` (how many matched) and `hits` (the matching documents). This is the payoff of full-text search over a plain `LIKE '%dart%'`: it tokenises text, matches word stems, and scores by relevance rather than just presence.

## The routes

```dart
// lib/features/search/search_route.dart
Router.post('/articles', articleController.store);
Router.get('/articles/search', articleController.search);
```

## Testing without a cluster

The tests inject a fake `ElasticsearchTransport`, so they can assert on the *requests* the app sends — the index call and the search query — without a running Elasticsearch:

```bash
dart test
```

Same pattern as every other sample: the real backend sits behind a seam (here, the transport), so behaviour is verified against a fake. You are testing "did we build the right search request," not "does Elasticsearch work."

## What to take away

- `extends Model with Searchable` turns a model into an indexable document; the table name is the index and `toJson()` is the body.
- `searchable()` indexes; `search(q, fields: [...])` runs a relevance-ranked multi-match query.
- `refresh: 'wait_for'` bridges Elasticsearch's near-real-time nature so index-then-search is immediate — useful in demos and tests, usually dropped in production.
- The transport seam lets you test the search requests without a live cluster.
