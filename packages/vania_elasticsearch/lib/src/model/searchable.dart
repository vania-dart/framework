import 'package:vania/database.dart' show Model;

import '../bulk/elasticsearch_bulk_operation.dart';
import '../http/elasticsearch_response.dart';
import '../response/elasticsearch_search_result.dart';
import '../search/elasticsearch_query_builder.dart';
import '../vania_elasticsearch.dart';

/// Marks a [Model] as searchable via Elasticsearch.
///
/// Override [searchableAs] to change the index and [toSearchable] to change
/// which attributes are indexed. The default implementations use the
/// model's `tableName` as the index name and its `toJson()` for the body.
///
/// ```dart
/// class Post extends Model with Searchable {
///   Post() {
///     tableName = 'posts';
///   }
/// }
///
/// await post.searchable();                 // index this document
/// final hits = await Post().search('kids');
/// ```
mixin Searchable on Model {
  /// The index the model lives in. Defaults to the model's table name.
  /// Any [ElasticsearchConfig.indexPrefix] is applied automatically.
  String searchableAs() => getTable;

  /// The document body indexed for this model. Defaults to [toJson].
  Map<String, dynamic> toSearchable() => toJson();

  /// The document id — defaults to the primary key.
  String searchableId() {
    final key = getKey();
    if (key == null) {
      throw StateError(
        'Cannot index $runtimeType: primary key ($primaryKey) is null.',
      );
    }
    return key.toString();
  }

  /// Index this document into Elasticsearch.
  Future<ElasticsearchResponse> searchable({String? refresh, String? routing}) {
    return Elasticsearch.client.indexDocument(
      searchableAs(),
      toSearchable(),
      id: searchableId(),
      refresh: refresh,
      routing: routing,
    );
  }

  /// Remove this document from the index.
  Future<ElasticsearchResponse> unsearchable({
    String? refresh,
    String? routing,
  }) {
    return Elasticsearch.client.deleteDocument(
      searchableAs(),
      searchableId(),
      refresh: refresh,
      routing: routing,
    );
  }

  /// Run a query against the model's index.
  ///
  /// Pass either [query] (text — becomes `match_all` when empty or a
  /// `multi_match` across [fields] otherwise) or [builder] for a full
  /// Elasticsearch DSL. If both are given, [builder] wins.
  Future<ElasticsearchSearchResult> search(
    String query, {
    List<String> fields = const ['*'],
    ElasticsearchQueryBuilder? builder,
    int? from,
    int? size,
    String? routing,
  }) {
    ElasticsearchQueryBuilder resolved;
    if (builder != null) {
      resolved = builder;
    } else if (query.isEmpty) {
      resolved = ElasticsearchQueryBuilder()..matchAll();
    } else {
      resolved = ElasticsearchQueryBuilder()..multiMatch(query, fields);
    }
    return Elasticsearch.searchResult(
      index: searchableAs(),
      query: resolved,
      from: from,
      size: size,
      routing: routing,
    );
  }
}

/// Bulk-index a batch of searchable models.
///
/// Uses the ES bulk API so N documents ship in one round-trip. Failures
/// surface as [ElasticsearchException] once the response is inspected.
Future<ElasticsearchResponse> bulkIndex<T extends Model>(
  Iterable<T> models, {
  String? refresh,
}) {
  final searchable = models.whereType<Searchable>().toList();
  if (searchable.isEmpty) {
    throw ArgumentError(
      'bulkIndex requires at least one Model that uses the Searchable mixin.',
    );
  }
  final ops = searchable
      .map(
        (m) => ElasticsearchBulkOperation.index(
          index: m.searchableAs(),
          id: m.searchableId(),
          document: m.toSearchable(),
        ),
      )
      .toList();
  return Elasticsearch.bulk(ops, refresh: refresh);
}
