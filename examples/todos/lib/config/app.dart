import 'package:vania/vania.dart';
import 'package:vania/service_provider.dart';
import 'package:todos/app/providers/route_service_provider.dart';

Map<String, dynamic> config = {
  'name': env('APP_NAME', 'todos'),
  'url': env('APP_URL', 'http://localhost'),
  'providers': <ServiceProvider>[
    RouteServiceProvider(),
  ],
};
