## 1.0.0

First stable release.

- Requires `vania` 2.0.0.
- Elasticsearch client with index, document, search, and bulk APIs, plus a
  query builder.
- `Searchable` mixin — `class Post extends Model with Searchable` gives
  `searchable()`, `unsearchable()`, and `search()`; `bulkIndex()` handles
  batches.
- One `HttpClient` per request in `IoElasticsearchTransport`, which removes the
  client-wide mutable-property race under concurrent traffic.
- `ElasticsearchServiceProvider` runs an optional health probe on boot
  (`ELASTICSEARCH_WARM_UP`) and logs a warning on failure rather than throwing.
- Add `Searchable` mixin — `Model` + `Searchable` gives `searchable()`,
  `unsearchable()`, and `search()`. Global `bulkIndex()` helper for batches.
- `IoElasticsearchTransport` now creates one `HttpClient` per request to
  eliminate the client-wide mutable-property race on concurrent traffic.
- `ElasticsearchConfig.warmUp` (env `ELASTICSEARCH_WARM_UP`) — when set,
  `ElasticsearchServiceProvider.boot` runs a HEAD `/` health probe and logs
  a warning on failure (never throws).