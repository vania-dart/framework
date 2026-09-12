import 'package:vania/src/route/route_handler.dart';

import '../config/config.dart';
import '../service/service_provider.dart';

Future<void> initializeConfig(Map<String, dynamic> config) async {
  // Checked up front so a malformed config reports what is actually
  // wrong, instead of surfacing later as a cast error.
  Config.validate(config);

  Config().setApplicationConfig = config;

  final providers = List<ServiceProvider>.from(config['providers'] as List);
  for (ServiceProvider provider in providers) {
    await provider.register();
  }

  for (ServiceProvider provider in providers) {
    await provider.boot();
  }

  initializeRoutes();
}
