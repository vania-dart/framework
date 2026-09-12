import '../config/elasticsearch_config.dart';
import 'elasticsearch_request.dart';
import 'elasticsearch_response.dart';

abstract class ElasticsearchTransport {
  Future<ElasticsearchResponse> send(
    Uri host,
    ElasticsearchRequest request,
    ElasticsearchConfig config,
  );

  Future<void> close() async {}
}
