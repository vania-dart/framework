import 'package:vania/src/database/database_client.dart';
import 'package:vania/vania.dart';

Future<void> initializeConfig(config) async {
  Config().setApplicationConfig = config;
  List<ServiceProvider> providers = config['providers'];
  for (ServiceProvider provider in providers) {
    await provider.register();
    await provider.boot();
  }

  await DatabaseClient().setup();
}
