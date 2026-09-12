import 'package:vania/http/controller.dart';
import 'package:vania/http/request.dart';
import 'package:vania/http/response.dart';
import 'package:elasticsearch_search/models/article.dart';

class ArticleController extends Controller {
  /// Index an article document into Elasticsearch.
  Future<Response> store(Request req) async {
    await req.validate({
      'id': 'required|numeric',
      'title': 'required|string',
      'body': 'required|string',
    });

    final article = Article(
      id: int.parse(req.input('id').toString()),
      title: req.input('title') as String,
      body: req.input('body') as String,
    );
    await article.searchable(refresh: 'wait_for');

    return Response.json({'indexed': article.searchableId()}, 201);
  }

  /// Full-text search over the `articles` index.
  Future<Response> search(Request req) async {
    final query = req.input('q')?.toString() ?? '';
    final result = await Article().search(query, fields: ['title', 'body']);

    return Response.json({
      'total': result.total,
      'hits': result.hits,
    });
  }
}

final ArticleController articleController = ArticleController();
