import 'package:test/test.dart';
import 'package:vania_elasticsearch/vania_elasticsearch.dart';

void main() {
  setUp(Elasticsearch.resetForTesting);

  test('builds config with index prefix and hosts', () {
    final config = ElasticsearchConfig(
      hosts: [Uri.parse('http://127.0.0.1:9200')],
      indexPrefix: 'app_',
      defaultIndex: 'posts',
    );

    expect(config.hosts.single.toString(), 'http://127.0.0.1:9200');
    expect(config.indexName('posts'), 'app_posts');
    expect(config.requireIndex(), 'app_posts');
  });

  test('builds bool search queries', () {
    final query = ElasticsearchQueryBuilder()
        .match('title', 'vania', operator: 'and')
        .term('status', 'published')
        .range('views', gte: 10)
        .sort('created_at', order: 'desc')
        .from(5)
        .size(10)
        .build();

    expect(query['from'], 5);
    expect(query['size'], 10);
    expect(query['sort'], isA<List>());
    expect(query['query']['bool']['must'], isA<List>());
    expect(query['query']['bool']['filter'], hasLength(2));
  });

  test('indexes documents through the configured transport', () async {
    final transport = RecordingTransport(
      ElasticsearchResponse(
        statusCode: 201,
        body: {'result': 'created'},
        rawBody: '{}',
      ),
    );
    Elasticsearch.configure(
      config: ElasticsearchConfig(
        hosts: [Uri.parse('http://localhost:9200')],
        indexPrefix: 'blog_',
      ),
      transport: transport,
    );

    await Elasticsearch.index('posts').document({'title': 'Vania'}, id: '1');

    expect(transport.requests.single.method, 'PUT');
    expect(transport.requests.single.path, '/blog_posts/_doc/1');
    expect(transport.requests.single.body, {'title': 'Vania'});
  });

  test('serializes bulk operations as ndjson', () async {
    final transport = RecordingTransport(
      ElasticsearchResponse(
        statusCode: 200,
        body: {'errors': false},
        rawBody: '{}',
      ),
    );
    final client = ElasticsearchClient(
      config: ElasticsearchConfig(hosts: [Uri.parse('http://localhost:9200')]),
      transport: transport,
    );

    await client.bulk([
      ElasticsearchBulkOperation.index(
        index: 'posts',
        id: '1',
        document: {'title': 'One'},
      ),
      ElasticsearchBulkOperation.delete(index: 'posts', id: '2'),
    ]);

    final request = transport.requests.single;
    expect(request.ndjson, isTrue);
    expect(request.path, '/_bulk');
    expect(request.body, contains('"index"'));
    expect(request.body, contains('"delete"'));
    expect(request.body.toString().endsWith('\n'), isTrue);
  });

  test('parses search results into hits and sources', () {
    final result = ElasticsearchSearchResult.fromResponse(
      ElasticsearchResponse(
        statusCode: 200,
        rawBody: '{}',
        body: {
          'took': 3,
          'timed_out': false,
          'hits': {
            'total': {'value': 1},
            'hits': [
              {
                '_id': '1',
                '_source': {'title': 'Vania'},
              },
            ],
          },
        },
      ),
    );

    expect(result.total, 1);
    expect(result.sources, [
      {'title': 'Vania'},
    ]);
  });

  test('service provider configures the Elasticsearch facade', () async {
    final transport = RecordingTransport(
      ElasticsearchResponse(statusCode: 200, body: {}, rawBody: '{}'),
    );
    final provider = ElasticsearchServiceProvider(
      config: ElasticsearchConfig(hosts: [Uri.parse('http://localhost:9200')]),
      transport: transport,
    );

    await provider.register();
    await Elasticsearch.ping();

    expect(transport.requests.single.method, 'HEAD');
  });
}

class RecordingTransport implements ElasticsearchTransport {
  RecordingTransport(this.response);

  final ElasticsearchResponse response;
  final List<ElasticsearchRequest> requests = [];
  final List<Uri> hosts = [];

  @override
  Future<ElasticsearchResponse> send(
    Uri host,
    ElasticsearchRequest request,
    ElasticsearchConfig config,
  ) async {
    hosts.add(host);
    requests.add(request);
    return response;
  }

  @override
  Future<void> close() async {}
}
