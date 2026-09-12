import 'package:vania/vania.dart';
import 'package:vania/service_provider.dart';
import 'package:ddd_wallet/app/providers/route_service_provider.dart';

Map<String, dynamic> config = {
  'name': env('APP_NAME', 'ddd_wallet'),
  'url': env('APP_URL', 'http://localhost'),
  'providers': <ServiceProvider>[
    RouteServiceProvider(),
  ],
};
