import 'dart:async';
import 'dart:convert';

import 'package:vania/foundation.dart' show Logger;

import '../bulk/elasticsearch_bulk_operation.dart';
import '../config/elasticsearch_config.dart';
import '../exception/elasticsearch_exception.dart';
import '../http/elasticsearch_request.dart';
import '../http/elasticsearch_response.dart';
import '../http/elasticsearch_transport.dart';
import '../http/io_elasticsearch_transport.dart';
import '../search/elasticsearch_query_builder.dart';
import 'elasticsearch_index.dart';

class ElasticsearchClient {
  ElasticsearchClient({
    ElasticsearchConfig? config,
    ElasticsearchTransport? transport,
  }) : config = config ?? ElasticsearchConfig.fromApplication(),
       _transport = transport ?? IoElasticsearchTransport() {
    if (this.config.hosts.isEmpty) {
      throw ArgumentError('At least one Elasticsearch host is required.');
    }
  }

  final ElasticsearchConfig config;
  final ElasticsearchTransport _transport;
  int _nextHost = 0;

  ElasticsearchIndex index(String name) {
    return ElasticsearchIndex(this, config.indexName(name));
  }

  Future<ElasticsearchResponse> perform(
    String method,
    String path, {
    Map<String, dynamic> queryParameters = const {},
    dynamic body,
    Map<String, String> headers = const {},
    bool ndjson = false,
  }) {
    return _send(
      ElasticsearchRequest(
        method: method,
        path: path,
        queryParameters: queryParameters,
        body: body,
        headers: headers,
        ndjson: ndjson,
      ),
    );
  }

  Future<ElasticsearchResponse> get(
    String path, {
    Map<String, dynamic> queryParameters = const {},
  }) {
    return perform('GET', path, queryParameters: queryParameters);
  }

  Future<ElasticsearchResponse> post(
    String path, {
    Map<String, dynamic> queryParameters = const {},
    dynamic body,
  }) {
    return perform('POST', path, queryParameters: queryParameters, body: body);
  }

  Future<ElasticsearchResponse> put(
    String path, {
    Map<String, dynamic> queryParameters = const {},
    dynamic body,
  }) {
    return perform('PUT', path, queryParameters: queryParameters, body: body);
  }

  Future<ElasticsearchResponse> delete(
    String path, {
    Map<String, dynamic> queryParameters = const {},
    dynamic body,
  }) {
    return perform(
      'DELETE',
      path,
      queryParameters: queryParameters,
      body: body,
    );
  }

  Future<ElasticsearchResponse> head(
    String path, {
    Map<String, dynamic> queryParameters = const {},
  }) {
    return perform('HEAD', path, queryParameters: queryParameters);
  }

  Future<Map<String, dynamic>> info() async {
    return (await get('/')).json;
  }

  Future<bool> ping() async {
    final response = await head('/');
    return response.isOk;
  }

  Future<ElasticsearchResponse> createIndex(
    String index, {
    Map<String, dynamic>? body,
  }) {
    return put('/${config.indexName(index)}', body: body ?? {});
  }

  Future<bool> indexExists(String index) async {
    final response = await head('/${config.indexName(index)}');
    return response.isOk;
  }

  Future<ElasticsearchResponse> deleteIndex(String index) {
    return delete('/${config.indexName(index)}');
  }

  Future<ElasticsearchResponse> putMapping(
    String index,
    Map<String, dynamic> mapping,
  ) {
    return put('/${config.indexName(index)}/_mapping', body: mapping);
  }

  Future<ElasticsearchResponse> getMapping(String index) {
    return get('/${config.indexName(index)}/_mapping');
  }

  Future<ElasticsearchResponse> refresh(String index) {
    return post('/${config.indexName(index)}/_refresh');
  }

  Future<ElasticsearchResponse> indexDocument(
    String index,
    Map<String, dynamic> document, {
    String? id,
    String? refresh,
    String? routing,
  }) {
    final path = id == null
        ? '/${config.indexName(index)}/_doc'
        : '/${config.indexName(index)}/_doc/$id';
    return perform(
      id == null ? 'POST' : 'PUT',
      path,
      body: document,
      queryParameters: _compact({'refresh': refresh, 'routing': routing}),
    );
  }

  Future<ElasticsearchResponse> getDocument(
    String index,
    String id, {
    String? routing,
  }) {
    return get(
      '/${config.indexName(index)}/_doc/$id',
      queryParameters: _compact({'routing': routing}),
    );
  }

  Future<bool> documentExists(
    String index,
    String id, {
    String? routing,
  }) async {
    final response = await head(
      '/${config.indexName(index)}/_doc/$id',
      queryParameters: _compact({'routing': routing}),
    );
    return response.isOk;
  }

  Future<ElasticsearchResponse> updateDocument(
    String index,
    String id, {
    Map<String, dynamic>? doc,
    Map<String, dynamic>? script,
    Map<String, dynamic>? upsert,
    String? refresh,
    String? routing,
  }) {
    return post(
      '/${config.indexName(index)}/_update/$id',
      queryParameters: _compact({'refresh': refresh, 'routing': routing}),
      body: _compact({'doc': doc, 'script': script, 'upsert': upsert}),
    );
  }

  Future<ElasticsearchResponse> deleteDocument(
    String index,
    String id, {
    String? refresh,
    String? routing,
  }) {
    return delete(
      '/${config.indexName(index)}/_doc/$id',
      queryParameters: _compact({'refresh': refresh, 'routing': routing}),
    );
  }

  Future<ElasticsearchResponse> search({
    String? index,
    Map<String, dynamic>? body,
    ElasticsearchQueryBuilder? query,
    int? from,
    int? size,
    String? routing,
  }) {
    final searchBody = Map<String, dynamic>.from(
      body ??
          query?.build() ??
          const {
            'query': {'match_all': {}},
          },
    );
    if (from != null) searchBody['from'] = from;
    if (size != null) searchBody['size'] = size;
    final path = index == null
        ? '/_search'
        : '/${config.indexName(index)}/_search';
    return post(
      path,
      body: searchBody,
      queryParameters: _compact({'routing': routing}),
    );
  }

  Future<int> count({String? index, Map<String, dynamic>? query}) async {
    final path = index == null
        ? '/_count'
        : '/${config.indexName(index)}/_count';
    final response = await post(path, body: _compact({'query': query}));
    return response.json['count'] as int? ?? 0;
  }

  Future<ElasticsearchResponse> bulk(
    List<ElasticsearchBulkOperation> operations, {
    String? index,
    String? refresh,
  }) {
    final lines = <String>[];
    for (final operation in operations) {
      lines.addAll(operation.toLines(config.indexName));
    }
    final path = index == null ? '/_bulk' : '/${config.indexName(index)}/_bulk';
    return perform(
      'POST',
      path,
      body: '${lines.join('\n')}\n',
      ndjson: true,
      queryParameters: _compact({'refresh': refresh}),
    );
  }

  Future<ElasticsearchResponse> msearch(
    List<Map<String, dynamic>> searches, {
    String? index,
  }) {
    final lines = <String>[];
    for (final search in searches) {
      lines.add(_json(search['header'] ?? {}));
      lines.add(_json(search['body'] ?? search));
    }
    final path = index == null
        ? '/_msearch'
        : '/${config.indexName(index)}/_msearch';
    return perform('POST', path, body: '${lines.join('\n')}\n', ndjson: true);
  }

  Future<ElasticsearchResponse> reindex({
    required String source,
    required String destination,
    Map<String, dynamic>? query,
    bool waitForCompletion = true,
  }) {
    return post(
      '/_reindex',
      queryParameters: {'wait_for_completion': waitForCompletion},
      body: {
        'source': {
          'index': config.indexName(source),
          ..._compact({'query': query}),
        },
        'dest': {'index': config.indexName(destination)},
      },
    );
  }

  Future<ElasticsearchResponse> openPointInTime(
    String index, {
    String keepAlive = '1m',
  }) {
    return post(
      '/${config.indexName(index)}/_pit',
      queryParameters: {'keep_alive': keepAlive},
    );
  }

  Future<ElasticsearchResponse> closePointInTime(String id) {
    return delete('/_pit', body: {'id': id});
  }

  Future<void> close() {
    return _transport.close();
  }

  Future<ElasticsearchResponse> _send(ElasticsearchRequest request) async {
    Object? lastError;
    for (var attempt = 0; attempt <= config.maxRetries; attempt++) {
      final host = _host();
      try {
        final response = await _transport.send(host, request, config);
        if (response.isOk ||
            !config.retryStatusCodes.contains(response.statusCode)) {
          _throwIfFailed(response, request);
          return response;
        }
        lastError = ElasticsearchException(
          'Elasticsearch returned retryable status ${response.statusCode}.',
          statusCode: response.statusCode,
          body: response.body,
        );
      } catch (error, stackTrace) {
        lastError = error;
        Logger.log('$error\n$stackTrace', type: Logger.ERROR);
      }
      if (attempt < config.maxRetries) {
        await Future<void>.delayed(config.retryDelay * (attempt + 1));
      }
    }

    if (lastError is ElasticsearchException) throw lastError;
    throw ElasticsearchException(
      'Elasticsearch request failed.',
      cause: lastError,
    );
  }

  Uri _host() {
    final host = config.hosts[_nextHost % config.hosts.length];
    _nextHost++;
    return host;
  }

  void _throwIfFailed(
    ElasticsearchResponse response,
    ElasticsearchRequest request,
  ) {
    if (response.isOk || request.method == 'HEAD') return;
    throw ElasticsearchException(
      'Elasticsearch request ${request.method} ${request.path} failed.',
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  String _json(dynamic value) {
    return value is String ? value : _jsonEncode(value);
  }

  String _jsonEncode(dynamic value) {
    return jsonEncode(value ?? {});
  }

  Map<String, dynamic> _compact(Map<String, dynamic> values) {
    return Map<String, dynamic>.from(values)
      ..removeWhere((key, value) => value == null);
  }
}
