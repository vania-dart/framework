import 'package:vania/http/controller.dart';
import 'package:vania/http/request.dart';
import 'package:vania/http/response.dart';
import 'package:redis_cache/views/page_views.dart';
import 'package:redis_cache/store/redis_counter_store.dart';

/// Wires the Redis-backed store into the service. Swap `RedisCounterStore`
/// for any other `CounterStore` without touching the controller.
final PageViews _pageViews = PageViews(RedisCounterStore());

class ViewsController extends Controller {
  Future<Response> record(Request req, String page) async {
    return Response.json({'page': page, 'views': await _pageViews.record(page)});
  }

  Future<Response> show(Request req, String page) async {
    return Response.json({'page': page, 'views': await _pageViews.count(page)});
  }
}

final ViewsController viewsController = ViewsController();
