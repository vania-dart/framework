import 'package:vania/vania.dart';
import 'package:vania/service_provider.dart';
import 'package:vania_elasticsearch/vania_elasticsearch.dart';
import 'package:elasticsearch_search/app/providers/route_service_provider.dart';

Map<String, dynamic> config = {
  'name': env('APP_NAME', 'elasticsearch_search'),
  'url': env('APP_URL', 'http://localhost'),
  'providers': <ServiceProvider>[
    ElasticsearchServiceProvider(
      config: ElasticsearchConfig(
        hosts: [Uri.parse(env('ELASTICSEARCH_HOST', 'http://localhost:9200'))],
        defaultIndex: 'articles',
      ),
    ),
    RouteServiceProvider(),
  ],
};
