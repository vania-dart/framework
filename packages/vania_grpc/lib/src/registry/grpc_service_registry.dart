import 'package:grpc/grpc.dart';

class GrpcServiceRegistry {
  factory GrpcServiceRegistry() => _singleton;

  GrpcServiceRegistry._internal();

  static final GrpcServiceRegistry _singleton = GrpcServiceRegistry._internal();

  final List<Service> _services = [];
  final List<Interceptor> _interceptors = [];
  final List<ServerInterceptor> _serverInterceptors = [];

  List<Service> get services => List.unmodifiable(_services);
  List<Interceptor> get interceptors => List.unmodifiable(_interceptors);
  List<ServerInterceptor> get serverInterceptors =>
      List.unmodifiable(_serverInterceptors);

  void registerService(Service service) {
    final exists = _services.any(
      (registered) => registered.$name == service.$name,
    );
    if (exists) return;
    _services.add(service);
  }

  void registerServices(Iterable<Service> services) {
    for (final service in services) {
      registerService(service);
    }
  }

  void addInterceptor(Interceptor interceptor) {
    _interceptors.add(interceptor);
  }

  void addServerInterceptor(ServerInterceptor interceptor) {
    _serverInterceptors.add(interceptor);
  }

  void clear() {
    _services.clear();
    _interceptors.clear();
    _serverInterceptors.clear();
  }
}
