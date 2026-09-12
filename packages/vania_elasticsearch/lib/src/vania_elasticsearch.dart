import 'bulk/elasticsearch_bulk_operation.dart';
import 'client/elasticsearch_client.dart';
import 'client/elasticsearch_index.dart';
import 'config/elasticsearch_config.dart';
import 'http/elasticsearch_response.dart';
import 'http/elasticsearch_transport.dart';
import 'response/elasticsearch_search_result.dart';
import 'search/elasticsearch_query_builder.dart';

class Elasticsearch {
  const Elasticsearch._();

  static ElasticsearchClient? _client;

  static ElasticsearchClient get client {
    return _client ??= ElasticsearchClient();
  }

  static void configure({
    ElasticsearchConfig? config,
    ElasticsearchTransport? transport,
  }) {
    _client = ElasticsearchClient(config: config, transport: transport);
  }

  static void resetForTesting() {
    _client = null;
  }

  static ElasticsearchIndex index(String name) {
    return client.index(name);
  }

  static Future<bool> ping() {
    return client.ping();
  }

  static Future<Map<String, dynamic>> info() {
    return client.info();
  }

  static Future<ElasticsearchResponse> search({
    String? index,
    Map<String, dynamic>? body,
    ElasticsearchQueryBuilder? query,
    int? from,
    int? size,
    String? routing,
  }) {
    return client.search(
      index: index,
      body: body,
      query: query,
      from: from,
      size: size,
      routing: routing,
    );
  }

  static Future<ElasticsearchSearchResult> searchResult({
    String? index,
    Map<String, dynamic>? body,
    ElasticsearchQueryBuilder? query,
    int? from,
    int? size,
    String? routing,
  }) async {
    final response = await search(
      index: index,
      body: body,
      query: query,
      from: from,
      size: size,
      routing: routing,
    );
    return ElasticsearchSearchResult.fromResponse(response);
  }

  static Future<ElasticsearchResponse> bulk(
    List<ElasticsearchBulkOperation> operations, {
    String? index,
    String? refresh,
  }) {
    return client.bulk(operations, index: index, refresh: refresh);
  }
}
