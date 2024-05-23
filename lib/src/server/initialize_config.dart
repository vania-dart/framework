import 'package:eloquent/eloquent.dart';
import 'package:vania/src/config/config.dart';
import 'package:vania/src/logger/logger.dart';
import 'package:vania/src/service/service_provider.dart';

Future<void> initializeConfig(config) async {
  Config().setApplicationConfig = config;
  List<ServiceProvider> providers = config['providers'];
  for (ServiceProvider provider in providers) {
    await provider.register();
    await provider.boot();
  }

  try {
    DatabaseConfig? db = config['database'];
    if (db != null) {
      await db.driver?.init(config['database']);
    }
  } on InvalidArgumentException catch (e) {
    Logger.log(e.cause.toString(), type: Logger.ERROR);
    rethrow;
  }
}
