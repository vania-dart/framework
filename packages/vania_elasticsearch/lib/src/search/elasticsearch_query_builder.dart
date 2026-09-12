class ElasticsearchQueryBuilder {
  final Map<String, dynamic> _bool = {
    'must': <Map<String, dynamic>>[],
    'filter': <Map<String, dynamic>>[],
    'should': <Map<String, dynamic>>[],
    'must_not': <Map<String, dynamic>>[],
  };
  final Map<String, dynamic> _body = {};

  ElasticsearchQueryBuilder matchAll() {
    _body['query'] = {'match_all': {}};
    return this;
  }

  ElasticsearchQueryBuilder match(
    String field,
    dynamic value, {
    String? operator,
  }) {
    final matchOptions = <String, dynamic>{'query': value};
    if (operator != null) matchOptions['operator'] = operator;
    final query = {
      'match': {field: matchOptions},
    };
    return must(query);
  }

  ElasticsearchQueryBuilder multiMatch(
    String query,
    List<String> fields, {
    String? type,
  }) {
    final multiMatch = <String, dynamic>{'query': query, 'fields': fields};
    if (type != null) multiMatch['type'] = type;
    return must({'multi_match': multiMatch});
  }

  ElasticsearchQueryBuilder term(String field, dynamic value) {
    return filter({
      'term': {field: value},
    });
  }

  ElasticsearchQueryBuilder terms(String field, Iterable values) {
    return filter({
      'terms': {field: values.toList()},
    });
  }

  ElasticsearchQueryBuilder range(
    String field, {
    dynamic gt,
    dynamic gte,
    dynamic lt,
    dynamic lte,
  }) {
    final options = <String, dynamic>{};
    if (gt != null) options['gt'] = gt;
    if (gte != null) options['gte'] = gte;
    if (lt != null) options['lt'] = lt;
    if (lte != null) options['lte'] = lte;
    return filter({
      'range': {field: options},
    });
  }

  ElasticsearchQueryBuilder exists(String field) {
    return filter({
      'exists': {'field': field},
    });
  }

  ElasticsearchQueryBuilder must(Map<String, dynamic> query) {
    (_bool['must'] as List<Map<String, dynamic>>).add(query);
    return this;
  }

  ElasticsearchQueryBuilder filter(Map<String, dynamic> query) {
    (_bool['filter'] as List<Map<String, dynamic>>).add(query);
    return this;
  }

  ElasticsearchQueryBuilder should(Map<String, dynamic> query) {
    (_bool['should'] as List<Map<String, dynamic>>).add(query);
    return this;
  }

  ElasticsearchQueryBuilder mustNot(Map<String, dynamic> query) {
    (_bool['must_not'] as List<Map<String, dynamic>>).add(query);
    return this;
  }

  ElasticsearchQueryBuilder minimumShouldMatch(int value) {
    _bool['minimum_should_match'] = value;
    return this;
  }

  ElasticsearchQueryBuilder from(int value) {
    _body['from'] = value;
    return this;
  }

  ElasticsearchQueryBuilder size(int value) {
    _body['size'] = value;
    return this;
  }

  ElasticsearchQueryBuilder sort(
    String field, {
    String order = 'asc',
    String? mode,
  }) {
    final options = <String, dynamic>{'order': order};
    if (mode != null) options['mode'] = mode;
    final sorts =
        _body.putIfAbsent('sort', () => <Map<String, dynamic>>[])
            as List<Map<String, dynamic>>;
    sorts.add({field: options});
    return this;
  }

  ElasticsearchQueryBuilder source(dynamic value) {
    _body['_source'] = value;
    return this;
  }

  ElasticsearchQueryBuilder highlight(Map<String, dynamic> value) {
    _body['highlight'] = value;
    return this;
  }

  ElasticsearchQueryBuilder aggregation(
    String name,
    Map<String, dynamic> value,
  ) {
    final aggs =
        _body.putIfAbsent('aggs', () => <String, dynamic>{})
            as Map<String, dynamic>;
    aggs[name] = value;
    return this;
  }

  ElasticsearchQueryBuilder raw(String key, dynamic value) {
    _body[key] = value;
    return this;
  }

  Map<String, dynamic> build() {
    final body = Map<String, dynamic>.from(_body);
    if (!body.containsKey('query')) {
      final boolQuery = _cleanBool();
      body['query'] = boolQuery.isEmpty
          ? {'match_all': {}}
          : {'bool': boolQuery};
    }
    return body;
  }

  Map<String, dynamic> _cleanBool() {
    final cleaned = <String, dynamic>{};
    for (final entry in _bool.entries) {
      if (entry.value is List && (entry.value as List).isEmpty) continue;
      cleaned[entry.key] = entry.value;
    }
    return cleaned;
  }
}
