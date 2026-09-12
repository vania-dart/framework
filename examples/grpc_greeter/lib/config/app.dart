import 'package:vania/vania.dart';
import 'package:vania/service_provider.dart';
import 'package:vania_grpc/vania_grpc.dart';
import 'package:grpc_greeter/greeter/greeter_service.dart';

Map<String, dynamic> config = {
  'name': env('APP_NAME', 'grpc_greeter'),
  'url': env('APP_URL', 'http://localhost'),
  'providers': <ServiceProvider>[
    GrpcServiceProvider(
      services: [GreeterService()],
      config: GrpcConfig(
        host: env('GRPC_HOST', '0.0.0.0'),
        port: env<int>('GRPC_PORT', 50051),
        autoStart: true,
      ),
    ),
  ],
};
