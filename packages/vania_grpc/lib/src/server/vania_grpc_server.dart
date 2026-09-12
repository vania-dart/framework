import 'package:grpc/grpc.dart';
import 'package:vania/foundation.dart' show Logger;

import '../config/grpc_config.dart';
import '../health/grpc_health_service.dart';
import '../interceptors/grpc_exception_interceptor.dart';
import '../registry/grpc_service_registry.dart';

class VaniaGrpcServer {
  factory VaniaGrpcServer() => _singleton;

  VaniaGrpcServer._internal();

  static final VaniaGrpcServer _singleton = VaniaGrpcServer._internal();

  Server? _server;
  GrpcConfig? _config;
  GrpcHealthService? _healthService;

  bool get isRunning => _server?.port != null;
  int? get port => _server?.port;
  GrpcConfig? get config => _config;

  void register(Service service) {
    GrpcServiceRegistry().registerService(service);
  }

  void registerAll(Iterable<Service> services) {
    GrpcServiceRegistry().registerServices(services);
  }

  void addInterceptor(Interceptor interceptor) {
    GrpcServiceRegistry().addInterceptor(interceptor);
  }

  void addServerInterceptor(ServerInterceptor interceptor) {
    GrpcServiceRegistry().addServerInterceptor(interceptor);
  }

  Future<void> serve([GrpcConfig? config]) async {
    if (isRunning) return;
    final resolved = config ?? GrpcConfig.fromApplication();
    if (!resolved.enabled) return;

    _config = resolved;
    final registry = GrpcServiceRegistry();
    final services = <Service>[...registry.services];
    if (resolved.healthEnabled &&
        !services.any((service) => service.$name == 'grpc.health.v1.Health')) {
      _healthService = GrpcHealthService();
      services.add(_healthService!);
    }

    _server = Server.create(
      services: services,
      keepAliveOptions: resolved.keepAlive,
      interceptors: registry.interceptors,
      serverInterceptors: _serverInterceptors(registry),
    );

    await _server!.serve(
      address: resolved.host,
      port: resolved.port,
      security: resolved.credentials(),
      backlog: resolved.backlog,
      shared: resolved.shared,
      v6Only: resolved.v6Only,
      requestClientCertificate: resolved.requestClientCertificate,
      requireClientCertificate: resolved.requireClientCertificate,
    );
    Logger.log(
      'gRPC server started on ${resolved.host}:${_server!.port}',
      type: Logger.INFO,
      fileName: 'grpc',
    );
  }

  Future<void> shutdown() async {
    await _server?.shutdown();
    _server = null;
    _config = null;
  }

  void setHealthStatus(String service, GrpcServingStatus status) {
    _healthService?.setStatus(service, status);
  }

  /// Prepend [GrpcExceptionInterceptor] once. If the caller has already
  /// added one (either explicitly or by mistake), we do NOT double it up —
  /// duplicate wraps swallow exceptions from each other and produce noise
  /// in the response trailers.
  List<ServerInterceptor> _serverInterceptors(GrpcServiceRegistry registry) {
    final existing = registry.serverInterceptors;
    final hasException = existing.any((i) => i is GrpcExceptionInterceptor);
    return [if (!hasException) GrpcExceptionInterceptor(), ...existing];
  }
}
