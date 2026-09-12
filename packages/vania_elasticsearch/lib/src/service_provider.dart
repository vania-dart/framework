import 'package:vania/foundation.dart' show Logger;
import 'package:vania/service_provider.dart';

import 'config/elasticsearch_config.dart';
import 'http/elasticsearch_transport.dart';
import 'vania_elasticsearch.dart';

/// Wires Elasticsearch into a Vania application.
///
/// `register()` swaps the [Elasticsearch] facade's underlying client with
/// one built from [config] (or [ElasticsearchConfig.fromApplication] when
/// omitted). `boot()` optionally issues a HEAD `/` health probe against the
/// cluster when `config.warmUp` is set — failures are logged as a warning
/// but do NOT throw, matching the tone of every other Vania provider.
class ElasticsearchServiceProvider extends ServiceProvider {
  const ElasticsearchServiceProvider({this.config, this.transport});

  final ElasticsearchConfig? config;
  final ElasticsearchTransport? transport;

  @override
  Future<void> register() async {
    Elasticsearch.configure(config: config, transport: transport);
  }

  @override
  Future<void> boot() async {
    final effective = config ?? Elasticsearch.client.config;
    if (!effective.warmUp) return;
    try {
      final ok = await Elasticsearch.ping();
      if (!ok) {
        Logger.log('vania_elasticsearch: warm-up ping returned non-OK');
      }
    } catch (e) {
      Logger.log('vania_elasticsearch: warm-up ping failed: $e');
    }
  }
}
