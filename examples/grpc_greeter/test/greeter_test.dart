import 'dart:io';

import 'package:test/test.dart';
import 'package:vania_grpc/vania_grpc.dart';
import 'package:grpc_greeter/greeter/greeter_service.dart';
import 'package:grpc_greeter/greeter/hello_messages.dart';

void main() {
  group('hello messages', () {
    test('HelloRequest round-trips through the wire format', () {
      final bytes = const HelloRequest(name: 'Vania').writeToBuffer();
      expect(HelloRequest.fromBuffer(bytes).name, 'Vania');
    });

    test('HelloResponse round-trips through the wire format', () {
      final bytes = const HelloResponse(message: 'Hello, Vania!').writeToBuffer();
      expect(HelloResponse.fromBuffer(bytes).message, 'Hello, Vania!');
    });
  });

  group('greetingFor', () {
    test('greets a name', () => expect(greetingFor('Vania'), 'Hello, Vania!'));
    test('falls back to World when empty',
        () => expect(greetingFor('  '), 'Hello, World!'));
  });

  group('GreeterService', () {
    test('exposes greeter.Greeter with a SayHello method', () {
      final service = GreeterService();
      expect(service.$name, 'greeter.Greeter');
      expect(service.$lookupMethod('SayHello'), isNotNull);
    });

    test('SayHello returns a greeting for the request name', () async {
      final service = GreeterService();
      final method = service.$lookupMethod('SayHello')!;

      final response = await Function.apply(method.handler, [
        _FakeServiceCall(),
        Future.value(const HelloRequest(name: 'Vania')),
      ]) as HelloResponse;

      expect(response.message, 'Hello, Vania!');
    });
  });
}

/// Minimal [ServiceCall] so a handler can be invoked directly in a test.
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
