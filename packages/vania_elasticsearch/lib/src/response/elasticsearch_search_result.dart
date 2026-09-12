import '../http/elasticsearch_response.dart';

class ElasticsearchSearchResult {
  const ElasticsearchSearchResult({
    required this.took,
    required this.timedOut,
    required this.total,
    required this.hits,
    required this.raw,
    this.aggregations = const {},
  });

  final int took;
  final bool timedOut;
  final int total;
  final List<Map<String, dynamic>> hits;
  final Map<String, dynamic> aggregations;
  final Map<String, dynamic> raw;

  factory ElasticsearchSearchResult.fromResponse(
    ElasticsearchResponse response,
  ) {
    final json = response.json;
    final hitsObject = json['hits'] as Map<String, dynamic>? ?? {};
    final totalObject = hitsObject['total'];
    final hits = hitsObject['hits'] as List? ?? const [];

    return ElasticsearchSearchResult(
      took: json['took'] as int? ?? 0,
      timedOut: json['timed_out'] as bool? ?? false,
      total: _total(totalObject),
      hits: hits.map((hit) => Map<String, dynamic>.from(hit as Map)).toList(),
      aggregations: Map<String, dynamic>.from(
        json['aggregations'] as Map? ?? {},
      ),
      raw: json,
    );
  }

  List<Map<String, dynamic>> get sources {
    return hits
        .map((hit) => Map<String, dynamic>.from(hit['_source'] as Map? ?? {}))
        .toList();
  }

  static int _total(dynamic value) {
    if (value is int) return value;
    if (value is Map) return value['value'] as int? ?? 0;
    return 0;
  }
}
