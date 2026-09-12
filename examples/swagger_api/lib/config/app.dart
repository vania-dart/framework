import 'package:vania/vania.dart';
import 'package:vania/service_provider.dart';
import 'package:vania_swagger/vania_swagger.dart';
import 'package:swagger_api/app/providers/route_service_provider.dart';

Map<String, dynamic> config = {
  'name': env('APP_NAME', 'swagger_api'),
  'url': env('APP_URL', 'http://localhost'),
  'providers': <ServiceProvider>[
    RouteServiceProvider(),
    SwaggerServiceProvider(
      info: const ApiInfo(
        title: 'Products API',
        version: '1.0.0',
        description: 'A small catalogue API documented with Swagger.',
      ),
    ),
  ],
};
