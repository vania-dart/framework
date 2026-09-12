import 'package:vania/route.dart';
import 'package:elasticsearch_search/features/search/article_controller.dart';

class SearchRoute extends Route {
  @override
  String? get prefix => 'api';

  @override
  void register() {
    super.register();

    Router.post('/articles', articleController.store);
    Router.get('/articles/search', articleController.search);
  }
}
