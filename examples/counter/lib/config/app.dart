import 'package:vania/vania.dart';
import 'package:vania/service_provider.dart';
import 'package:counter/app/providers/route_service_provider.dart';

Map<String, dynamic> config = {
  'name': env('APP_NAME', 'counter'),
  'url': env('APP_URL', 'http://localhost'),
  'providers': <ServiceProvider>[
    RouteServiceProvider(),
  ],
};
