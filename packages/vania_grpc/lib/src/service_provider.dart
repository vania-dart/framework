import 'package:grpc/grpc.dart';
import 'package:vania/service_provider.dart';

import 'config/grpc_config.dart';
import 'registry/grpc_service_registry.dart';
import 'server/vania_grpc_server.dart';

class GrpcServiceProvider extends ServiceProvider {
  const GrpcServiceProvider({
    this.services = const [],
    this.interceptors = const [],
    this.serverInterceptors = const [],
    this.config,
  });

  final List<Service> services;
  final List<Interceptor> interceptors;
  final List<ServerInterceptor> serverInterceptors;
  final GrpcConfig? config;

  @override
  Future<void> register() async {
    final registry = GrpcServiceRegistry();
    registry.registerServices(services);
    for (final interceptor in interceptors) {
      registry.addInterceptor(interceptor);
    }
    for (final interceptor in serverInterceptors) {
      registry.addServerInterceptor(interceptor);
    }
  }

  @override
  Future<void> boot() async {
    final resolved = config ?? GrpcConfig.fromApplication();
    if (resolved.autoStart) {
      await VaniaGrpcServer().serve(resolved);
    }
  }
}
