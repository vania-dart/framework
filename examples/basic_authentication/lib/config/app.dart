import 'package:vania/vania.dart';
import 'package:vania/service_provider.dart';
import 'package:vania/database.dart';
import 'package:basic_authentication/app/providers/route_service_provider.dart';

Map<String, dynamic> config = {
  'name': env('APP_NAME', 'basic_authentication'),
  'url': env('APP_URL', 'http://localhost'),
  'database': {
    'default': env('DB_CONNECTION', 'mysql'),
    'connections': {
      'mysql': {
        'driver': 'mysql',
        'host': env('DB_HOST', 'localhost'),
        'port': env<int>('DB_PORT', 3306),
        'database': env('DB_DATABASE', 'basic_authentication'),
        'username': env('DB_USERNAME', 'root'),
        'password': env('DB_PASSWORD', ''),
      },
    },
  },
  'providers': <ServiceProvider>[
    RouteServiceProvider(),
    DatabaseServiceProvider(),
  ],
};
