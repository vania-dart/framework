import 'dart:io';

import 'package:vania_grpc/vania_grpc.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() {
    GrpcServiceRegistry().clear();
  });

  test('builds grpc config from map', () {
    final config = GrpcConfig.fromMap({
      'host': '127.0.0.1',
      'port': '5050',
      'enabled': true,
      'auto_start': true,
      'secure': false,
      'health_enabled': true,
      'max_bad_pings': '3',
      'min_ping_interval_seconds': '60',
    });

    expect(config.host, '127.0.0.1');
    expect(config.port, 5050);
    expect(config.autoStart, isTrue);
    expect(config.keepAlive.maxBadPings, 3);
    expect(
      config.keepAlive.minIntervalBetweenPingsWithoutData,
      const Duration(seconds: 60),
    );
  });

  test('registers services only once', () {
    final registry = GrpcServiceRegistry();
    final service = GrpcHealthService();

    registry.registerService(service);
    registry.registerService(service);

    expect(registry.services, hasLength(1));
    expect(registry.services.first.$name, 'grpc.health.v1.Health');
  });

  test('health service serializes serving status', () async {
    final service = GrpcHealthService();
    final method = service.$lookupMethod('Check')!;
    final response =
        await Function.apply(method.handler, [
              _FakeServiceCall(),
              Future.value(const GrpcHealthCheckRequest(service: '')),
            ])
            as GrpcHealthCheckResponse;

    expect(response.status, GrpcServingStatus.serving);
    expect(response.writeToBuffer(), [0x08, 0x01]);
  });

  test('creates insecure client channels', () async {
    final channel = GrpcClientFactory.insecure('127.0.0.1', port: 50051);

    expect(channel, isA<ClientChannel>());
    await channel.shutdown();
  });

  test('starts and shuts down a grpc server', () async {
    final server = VaniaGrpcServer();

    await server.serve(
      const GrpcConfig(host: '127.0.0.1', port: 0, healthEnabled: true),
    );

    expect(server.isRunning, isTrue);
    expect(server.port, isNotNull);

    await server.shutdown();
    expect(server.isRunning, isFalse);
  });
}

class _FakeServiceCall implements ServiceCall {
  @override
  Map<String, String>? clientMetadata = const {};

  @override
  X509Certificate? get clientCertificate => null;

  @override
  DateTime? get deadline => null;

  @override
  Map<String, String>? headers = {};

  @override
  bool get isCanceled => false;

  @override
  bool get isTimedOut => false;

  @override
  InternetAddress? get remoteAddress => null;

  @override
  Map<String, String>? trailers = {};

  @override
  void sendHeaders() {}

  @override
  void sendTrailers({int? status, String? message}) {}
}
