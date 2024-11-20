import 'package:eloquent/eloquent.dart';
import 'package:vania/vania_framework.dart';

Future<void> initializeConfig(config) async {
  Config().setApplicationConfig = config;

  if (env('DB_CONNECTION') != null) {
    try {
      await DatabaseClient().setup();
    } on InvalidArgumentException catch (e) {
      Logger.log(e.cause.toString(), type: Logger.ERROR);
    }
  }

  List<ServiceProvider> providers = config['providers'];
  for (ServiceProvider provider in providers) {
    await provider.register();
    await provider.boot();
  }
}
