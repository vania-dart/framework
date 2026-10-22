import 'package:vania/service_provider.dart';
import 'package:vania/vania.dart';

import '../app/route_service_provider.dart';

Map<String, dynamic> config = {
  'name': env('APP_NAME', 'showcase'),
  'url': env('APP_URL', 'http://127.0.0.1:8790'),
  // `webhooks` covers /webhooks/stripe, not /webhooks-admin/purge.
  'csrf_except': ['webhooks'],
  'providers': <ServiceProvider>[RouteServiceProvider()],
};
