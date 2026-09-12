import 'package:test/test.dart';
import 'package:vania_elasticsearch/vania_elasticsearch.dart';
import 'package:elasticsearch_search/models/article.dart';

/// Records requests and returns a canned response, so the search flow can
/// be tested without a running Elasticsearch cluster.
class RecordingTransport implements ElasticsearchTransport {
  RecordingTransport(this.response);
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

  ElasticsearchConfig config() =>
      ElasticsearchConfig(hosts: [Uri.parse('http://localhost:9200')]);

  test('indexing an article PUTs it into the articles index by id', () async {
    final transport = RecordingTransport(
      ElasticsearchResponse(
        statusCode: 201,
        body: {'result': 'created'},
        rawBody: '{}',
      ),
    );
    Elasticsearch.configure(config: config(), transport: transport);

    await Article(id: 42, title: 'Vania', body: 'A Dart backend framework')
        .searchable(refresh: 'wait_for');

    final req = transport.requests.single;
    expect(req.method, 'PUT');
    expect(req.path, '/articles/_doc/42');
    expect(req.body, containsPair('title', 'Vania'));
    expect(req.queryParameters['refresh'], 'wait_for');
  });

  test('search issues a POST _search against the articles index', () async {
    final transport = RecordingTransport(
      ElasticsearchResponse(
        statusCode: 200,
        body: {
          'took': 3,
          'timed_out': false,
          'hits': {
            'total': {'value': 1},
            'hits': [
              {
                '_source': {'title': 'Vania', 'body': 'A Dart backend framework'}
              },
            ],
          },
        },
        rawBody: '{}',
      ),
    );
    Elasticsearch.configure(config: config(), transport: transport);

    final result =
        await Article().search('dart', fields: ['title', 'body']);

    final req = transport.requests.single;
    expect(req.method, 'POST');
    expect(req.path, contains('/articles/_search'));
    expect(result.total, 1);
    expect(result.sources.single, containsPair('title', 'Vania'));
  });
}
