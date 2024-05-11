import 'package:vania/vania.dart';
import 'package:todo_list/app/providers/route_service_provider.dart';

import 'auth.dart';
import 'cors.dart';

Map<String, dynamic> config = {
  'name': env('APP_NAME'),
  'url': env('APP_URL'),
  'timezone': '',
  'websocket': false,
  'isolate': false,
  'isolateCount': 4,
  'cors': cors,
  'database': null, //databaseConfig,
  'cache': CacheConfig(),
  'auth': authConfig,
  'storage': FileStorageConfig(),
  'mail': {
    'driver':env('MAIL_MAILER'),
    'host':env('MAIL_HOST'),
    'port':env('MAIL_PORT'),
    'username':env('MAIL_USERNAME'),
    'password':env('MAIL_PASSWORD'),
    'encryption':env('MAIL_ENCRYPTION'),
    'from_name':env('MAIL_FROM_NAME'),
    'from_address':env('MAIL_FROM_ADDRESS'),
  },
  'providers': <ServiceProvider>[
    RouteServiceProvider(),
  ],
};
