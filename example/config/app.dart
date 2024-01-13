

import 'package:vania/vania.dart';

import '../app/providers/route_service_povider.dart';
import 'cros.dart';


Map<String,dynamic> config = {
  'port': 8080,
  'host': '0.0.0.0',
  'name': '',
  'env':'',
  'url':'',
  'timezone': '',
  'cros':cros,
  'cache': CacheConfig(),
  'storage': FileStorageConfig(),
  'key': 'Y881Ez6wiAo9rjWnxgQmzyQTF2JGdyiU',
  'providers': <ServiceProvider>[
    RouteServiceProvider(),
  ],
};