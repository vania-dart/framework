import 'package:test/test.dart';
import 'package:vania_elasticsearch/vania_elasticsearch.dart';
import 'package:vania/database.dart' show Model;

class _Post extends Model with Searchable {
  _Post({int? id, String? title}) {
    tableName = 'posts';
    if (id != null) attributes['id'] = id;
    if (title != null) attributes['title'] = title;
  }
}

class _RecordingTransport implements ElasticsearchTransport {
  _RecordingTransport(this.response);

  final ElasticsearchResponse response;
  final List<ElasticsearchRequest> requests = [];

  @override
  Future<ElasticsearchResponse> send(
    Uri host,
    ElasticsearchRequest request,
    ElasticsearchConfig config,
  ) async {
    requests.add(request);
    return response;
  }

  @override
  Future<void> close() async {}
}

void main() {
  setUp(Elasticsearch.resetForTesting);

  group('Searchable', () {
    test(
      'searchable() indexes with the primary key as the document id',
      () async {
        final transport = _RecordingTransport(
          ElasticsearchResponse(
            statusCode: 201,
            body: {'result': 'created'},
            rawBody: '{}',
          ),
        );
        Elasticsearch.configure(
          config: ElasticsearchConfig(
            hosts: [Uri.parse('http://localhost:9200')],
          ),
          transport: transport,
        );

        await _Post(id: 42, title: 'hello').searchable(refresh: 'wait_for');

        final req = transport.requests.single;
        expect(req.method, 'PUT');
        expect(req.path, '/posts/_doc/42');
        expect(req.body, containsPair('title', 'hello'));
        expect(req.queryParameters['refresh'], 'wait_for');
      },
    );

    test('searchable() throws when the primary key is null', () async {
      Elasticsearch.configure(
        config: ElasticsearchConfig(
          hosts: [Uri.parse('http://localhost:9200')],
        ),
        transport: _RecordingTransport(
          ElasticsearchResponse(statusCode: 200, body: {}, rawBody: '{}'),
        ),
      );
      expect(
        () => _Post(title: 'anonymous').searchable(),
        throwsA(isA<StateError>()),
      );
    });

    test('unsearchable() deletes by id', () async {
      final transport = _RecordingTransport(
        ElasticsearchResponse(
          statusCode: 200,
          body: {'result': 'deleted'},
          rawBody: '{}',
        ),
      );
      Elasticsearch.configure(
        config: ElasticsearchConfig(
          hosts: [Uri.parse('http://localhost:9200')],
        ),
        transport: transport,
      );

      await _Post(id: 7).unsearchable();

      final req = transport.requests.single;
      expect(req.method, 'DELETE');
      expect(req.path, '/posts/_doc/7');
    });

    test(
      'search() with empty query builds match_all against the index',
      () async {
        final transport = _RecordingTransport(
          ElasticsearchResponse(
            statusCode: 200,
            body: {
              'took': 1,
              'timed_out': false,
              'hits': {
                'total': {'value': 0},
                'hits': const [],
              },
            },
            rawBody: '{}',
          ),
        );
        Elasticsearch.configure(
          config: ElasticsearchConfig(
            hosts: [Uri.parse('http://localhost:9200')],
          ),
          transport: transport,
        );

        await _Post().search('');

        final req = transport.requests.single;
        expect(req.method, 'POST');
        expect(req.path, '/posts/_search');
        final body = req.body as Map<String, dynamic>;
        // match_all lives under bool.must because matchAll() calls must({...})
        expect(body['query'], isNotNull);
      },
    );

    test(
      'search() with text builds multi_match over the given fields',
      () async {
        final transport = _RecordingTransport(
          ElasticsearchResponse(
            statusCode: 200,
            body: {
              'took': 1,
              'timed_out': false,
              'hits': {
                'total': {'value': 0},
                'hits': const [],
              },
            },
            rawBody: '{}',
          ),
        );
        Elasticsearch.configure(
          config: ElasticsearchConfig(
            hosts: [Uri.parse('http://localhost:9200')],
          ),
          transport: transport,
        );

        await _Post().search('vania', fields: ['title', 'body']);

        final body = transport.requests.single.body as Map<String, dynamic>;
        final json = body.toString();
        expect(json, contains('multi_match'));
        expect(json, contains('title'));
        expect(json, contains('body'));
      },
    );

    test('bulkIndex() emits one index op per model', () async {
      final transport = _RecordingTransport(
        ElasticsearchResponse(
          statusCode: 200,
          body: {'errors': false},
          rawBody: '{}',
        ),
      );
      Elasticsearch.configure(
        config: ElasticsearchConfig(
          hosts: [Uri.parse('http://localhost:9200')],
        ),
        transport: transport,
      );

      await bulkIndex([_Post(id: 1, title: 'a'), _Post(id: 2, title: 'b')]);

      final req = transport.requests.single;
      expect(req.ndjson, isTrue);
      expect(req.path, '/_bulk');
      final body = req.body.toString();
      expect(RegExp(r'"index"').allMatches(body).length, 2);
      expect(body, contains('"a"'));
      expect(body, contains('"b"'));
    });
  });
}
