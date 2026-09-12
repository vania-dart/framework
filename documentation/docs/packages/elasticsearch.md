---
sidebar_position: 6
---

# Elasticsearch (vania_elasticsearch)

The `vania_elasticsearch` package provides a client for Elasticsearch with index management, a fluent query builder, bulk operations, and a `Searchable` model mixin.

## Installation

```yaml
dependencies:
  vania_elasticsearch: ^1.0.0
```

## Configuration

Add Elasticsearch settings to `.env`:

```env
ELASTICSEARCH_HOST=localhost
ELASTICSEARCH_PORT=9200
ELASTICSEARCH_INDEX_PREFIX=myapp_
```

Register the service provider:

```dart
'providers': [
  RouteServiceProvider(),
  ElasticsearchServiceProvider(),
],
```

Or configure manually:

```dart
Elasticsearch.configure(
  config: ElasticsearchConfig(
    hosts: ['http://localhost:9200'],
    defaultIndex: 'myapp',
    indexPrefix: 'myapp_',
    username: 'elastic',
    password: 'changeme',
  ),
);
```

## Index Management

```dart
import 'package:vania_elasticsearch/vania_elasticsearch.dart';

var index = Elasticsearch.index('products');

// Create an index with mapping
await index.create({
  'mappings': {
    'properties': {
      'name': {'type': 'text'},
      'price': {'type': 'float'},
      'category': {'type': 'keyword'},
      'description': {'type': 'text'},
      'created_at': {'type': 'date'},
    },
  },
});

// Check if index exists
bool exists = await index.exists();

// Delete an index
await index.delete();

// Refresh (make recent changes searchable)
await index.refresh();
```

## Indexing Documents

```dart
var index = Elasticsearch.index('products');

// Index a single document
await index.document('product_1', {
  'name': 'Dart T-Shirt',
  'price': 29.99,
  'category': 'apparel',
  'description': 'A comfortable t-shirt for Dart developers.',
});

// Check if a document exists
bool exists = await index.has('product_1');

// Get a document
var doc = await index.get('product_1');

// Update a document
await index.update('product_1', {'price': 24.99});

// Delete a document
await index.remove('product_1');
```

## Searching

### Basic Search

```dart
var results = await Elasticsearch.search(
  index: 'products',
  query: 'dart shirt',
);
```

### Query Builder

Build complex queries with a fluent API:

```dart
var builder = ElasticsearchQueryBuilder()
    .match('name', 'dart')
    .filter({'range': {'price': {'lte': 50}}})
    .sort('price', order: 'asc')
    .from(0)
    .size(20)
    .highlight({'fields': {'name': {}, 'description': {}}});

var results = await Elasticsearch.searchResult(
  index: 'products',
  body: builder.build(),
);

print('Total: ${results.total}');
for (var hit in results.hits) {
  print('${hit['_source']['name']} - \$${hit['_source']['price']}');
}
```

### Bool Query

```dart
var builder = ElasticsearchQueryBuilder()
    .must({'match': {'category': 'apparel'}})
    .must({'range': {'price': {'gte': 10, 'lte': 100}}})
    .should({'match': {'description': 'comfortable'}})
    .mustNot({'term': {'status': 'discontinued'}})
    .minimumShouldMatch(1);
```

### Advanced Queries

```dart
// Term query (exact match)
var builder = ElasticsearchQueryBuilder().term('category', 'apparel');

// Terms query (match any)
var builder = ElasticsearchQueryBuilder().terms('category', ['apparel', 'accessories']);

// Range query
var builder = ElasticsearchQueryBuilder().range('price', gte: 10, lte: 100);

// Exists query
var builder = ElasticsearchQueryBuilder().exists('discount');

// Multi-match
var builder = ElasticsearchQueryBuilder().multiMatch('dart framework', ['name', 'description']);

// Match all
var builder = ElasticsearchQueryBuilder().matchAll();
```

### Aggregations

```dart
var builder = ElasticsearchQueryBuilder()
    .size(0)
    .aggregation('avg_price', {'avg': {'field': 'price'}})
    .aggregation('categories', {'terms': {'field': 'category'}});

var results = await Elasticsearch.searchResult(
  index: 'products',
  body: builder.build(),
);

print('Average price: ${results.aggregations['avg_price']['value']}');
```

## Bulk Operations

```dart
await Elasticsearch.bulk([
  ElasticsearchBulkOperation.index('product_1', {'name': 'Item 1', 'price': 10}),
  ElasticsearchBulkOperation.index('product_2', {'name': 'Item 2', 'price': 20}),
  ElasticsearchBulkOperation.update('product_3', {'price': 15}),
  ElasticsearchBulkOperation.delete('product_old'),
], index: 'products');
```

## Searchable Model Mixin

Add full-text search to your ORM models:

```dart
class Product extends Model with Searchable {
  @override
  List<String> get fillable => ['name', 'price', 'category', 'description'];

  @override
  String searchableAs() => 'products';

  @override
  Map<String, dynamic> toSearchable() => {
    'name': getAttribute('name'),
    'price': getAttribute('price'),
    'category': getAttribute('category'),
    'description': getAttribute('description'),
  };
}
```

Then sync your model data with Elasticsearch:

```dart
// Index a single model
var product = await Product().query.find(1);
await product?.searchable();

// Remove from index
await product?.unsearchable();

// Search through the model
var results = await Product().search('dart shirt', size: 20);

// Bulk index all products
var products = await Product().query.get();
await bulkIndex<Product>(products);
```

## Connection Health

```dart
bool alive = await Elasticsearch.ping();
var info = await Elasticsearch.info();
```
