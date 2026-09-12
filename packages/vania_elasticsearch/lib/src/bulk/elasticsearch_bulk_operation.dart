import 'dart:convert';

class ElasticsearchBulkOperation {
  const ElasticsearchBulkOperation._({
    required this.action,
    required this.index,
    this.id,
    this.document,
    this.doc,
    this.script,
    this.upsert,
    this.routing,
  });

  final String action;
  final String index;
  final String? id;
  final Map<String, dynamic>? document;
  final Map<String, dynamic>? doc;
  final Map<String, dynamic>? script;
  final Map<String, dynamic>? upsert;
  final String? routing;

  factory ElasticsearchBulkOperation.index({
    required String index,
    String? id,
    required Map<String, dynamic> document,
    String? routing,
  }) {
    return ElasticsearchBulkOperation._(
      action: 'index',
      index: index,
      id: id,
      document: document,
      routing: routing,
    );
  }

  factory ElasticsearchBulkOperation.create({
    required String index,
    String? id,
    required Map<String, dynamic> document,
    String? routing,
  }) {
    return ElasticsearchBulkOperation._(
      action: 'create',
      index: index,
      id: id,
      document: document,
      routing: routing,
    );
  }

  factory ElasticsearchBulkOperation.update({
    required String index,
    required String id,
    Map<String, dynamic>? doc,
    Map<String, dynamic>? script,
    Map<String, dynamic>? upsert,
    String? routing,
  }) {
    return ElasticsearchBulkOperation._(
      action: 'update',
      index: index,
      id: id,
      doc: doc,
      script: script,
      upsert: upsert,
      routing: routing,
    );
  }

  factory ElasticsearchBulkOperation.delete({
    required String index,
    required String id,
    String? routing,
  }) {
    return ElasticsearchBulkOperation._(
      action: 'delete',
      index: index,
      id: id,
      routing: routing,
    );
  }

  Iterable<String> toLines(String Function(String index) indexName) sync* {
    final metadata = <String, dynamic>{'_index': indexName(index)};
    if (id != null) metadata['_id'] = id;
    if (routing != null) metadata['routing'] = routing;
    yield jsonEncode({action: metadata});

    if (action == 'delete') return;
    if (action == 'update') {
      yield jsonEncode({
        if (doc != null) 'doc': doc,
        if (script != null) 'script': script,
        if (upsert != null) 'upsert': upsert,
      });
      return;
    }
    yield jsonEncode(document ?? {});
  }
}
