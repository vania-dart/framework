# Vania Elasticsearch

**Full-text search for Vania: index your models, then search them with real relevance ranking.**

`vania_elasticsearch` connects a Vania app to an Elasticsearch cluster. It gives you a typed client, a query builder, bulk indexing, and — the part most apps want — a `Searchable` mixin that turns any model into a searchable document. Add it to a model and `Article().search('dart')` returns relevance-ranked hits, not a clumsy `LIKE '%dart%'`.

## Install

```yaml
dependencies:
  vania_elasticsearch: ^1.0.0
```

Register the provider and point it at your cluster:

```dart
final providers = <ServiceProvider>[
  ElasticsearchServiceProvider(
    config: ElasticsearchConfig(
      hosts: [Uri.parse(env('ELASTICSEARCH_HOST', 'http://localhost:9200'))],
      defaultIndex: 'articles',
    ),
  ),
];
```

## Make a model searchable

```dart
import 'package:vania/database.dart' show Model;
import 'package:vania_elasticsearch/vania_elasticsearch.dart';

class Article extends Model with Searchable {
  Article({int? id, String? title, String? body}) {
    tableName = 'articles'; // the table name doubles as the index
    if (id != null) attributes['id'] = id;
    if (title != null) attributes['title'] = title;
    if (body != null) attributes['body'] = body;
  }
}
```

By default the model's table name is the index and its `toJson()` is the indexed document — no separate mapping to maintain.

## Index and search

```dart
// Index a document
await article.searchable();

// Full-text search across fields, ranked by relevance
final result = await Article().search('dart backend', fields: ['title', 'body']);
print(result.total);
print(result.hits);
```

## What's included

- **`Searchable` mixin** — `searchable()` to index, `unsearchable()` to remove, `search()` to query.
- **Query builder** — multi-match, match-all, and custom queries with paging (`from`, `size`).
- **Direct client** — `Elasticsearch.search(...)`, `Elasticsearch.index(...)`, and bulk helpers when you need lower-level control.
- **Bulk indexing** for backfilling large datasets efficiently.

## Links

- Documentation: [vdart.dev/docs](https://vdart.dev/docs/intro)
- Source & issues: [github.com/vania-dart/framework](https://github.com/vania-dart/framework)

## License

MIT
