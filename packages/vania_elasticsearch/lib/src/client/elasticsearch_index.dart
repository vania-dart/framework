import '../bulk/elasticsearch_bulk_operation.dart';
import '../http/elasticsearch_response.dart';
import '../search/elasticsearch_query_builder.dart';
import 'elasticsearch_client.dart';

class ElasticsearchIndex {
  ElasticsearchIndex(this._client, this.name);

  final ElasticsearchClient _client;
  final String name;

  Future<ElasticsearchResponse> create({Map<String, dynamic>? body}) {
    return _client.createIndex(name, body: body);
  }

  Future<bool> exists() {
    return _client.indexExists(name);
  }

  Future<ElasticsearchResponse> delete() {
    return _client.deleteIndex(name);
  }

  Future<ElasticsearchResponse> mapping(Map<String, dynamic> mapping) {
    return _client.putMapping(name, mapping);
  }

  Future<ElasticsearchResponse> refresh() {
    return _client.refresh(name);
  }

  Future<ElasticsearchResponse> document(
    Map<String, dynamic> document, {
    String? id,
    String? refresh,
    String? routing,
  }) {
    return _client.indexDocument(
      name,
      document,
      id: id,
      refresh: refresh,
      routing: routing,
    );
  }

  Future<ElasticsearchResponse> get(String id, {String? routing}) {
    return _client.getDocument(name, id, routing: routing);
  }

  Future<bool> has(String id, {String? routing}) {
    return _client.documentExists(name, id, routing: routing);
  }

  Future<ElasticsearchResponse> update(
    String id, {
    Map<String, dynamic>? doc,
    Map<String, dynamic>? script,
    Map<String, dynamic>? upsert,
    String? refresh,
    String? routing,
  }) {
    return _client.updateDocument(
      name,
      id,
      doc: doc,
      script: script,
      upsert: upsert,
      refresh: refresh,
      routing: routing,
    );
  }

  Future<ElasticsearchResponse> remove(
    String id, {
    String? refresh,
    String? routing,
  }) {
    return _client.deleteDocument(name, id, refresh: refresh, routing: routing);
  }

  Future<ElasticsearchResponse> search({
    Map<String, dynamic>? body,
    ElasticsearchQueryBuilder? query,
    int? from,
    int? size,
    String? routing,
  }) {
    return _client.search(
      index: name,
      body: body,
      query: query,
      from: from,
      size: size,
      routing: routing,
    );
  }

  Future<int> count({Map<String, dynamic>? query}) {
    return _client.count(index: name, query: query);
  }

  Future<ElasticsearchResponse> bulk(
    List<ElasticsearchBulkOperation> operations, {
    String? refresh,
  }) {
    return _client.bulk(operations, index: name, refresh: refresh);
  }
}
