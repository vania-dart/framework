import 'package:vania/database.dart' show Model;
import 'package:vania_elasticsearch/vania_elasticsearch.dart';

class Post extends Model with Searchable {
  Post({int? id, String? title, String? body}) {
    tableName = 'posts';
    if (id != null) attributes['id'] = id;
    if (title != null) attributes['title'] = title;
    if (body != null) attributes['body'] = body;
  }
}

Future<void> main() async {
  Elasticsearch.configure(
    config: ElasticsearchConfig(
      hosts: [Uri.parse('http://localhost:9200')],
      defaultIndex: 'posts',
    ),
  );

  // Low-level indexing.
  await Elasticsearch.index(
    'posts',
  ).document({'title': 'Vania Elasticsearch', 'status': 'published'}, id: 'p1');

  // Model + Searchable — no per-model repo, no boilerplate.
  await Post(id: 1, title: 'Hello Vania', body: 'first post').searchable();
  await bulkIndex([
    Post(id: 2, title: 'Second', body: 'batched'),
    Post(id: 3, title: 'Third', body: 'batched'),
  ], refresh: 'wait_for');

  final hits = await Post().search('vania', fields: ['title', 'body']);
  print(hits.sources);
}
