# Vania gRPC

**Run a gRPC server right beside your Vania HTTP server.**

`vania_grpc` adds gRPC to a Vania app. gRPC is a fast, contract-first RPC protocol built on Protocol Buffers — great for service-to-service calls and low-latency APIs. This package lets you register your gRPC services with a provider and have them start automatically at boot, on their own port, alongside your regular HTTP server. One app, two protocols.

## Install

```yaml
dependencies:
  vania_grpc: ^1.0.0
```

Register your services:

```dart
final providers = <ServiceProvider>[
  GrpcServiceProvider(
    services: [GreeterService()],
    config: GrpcConfig(
      host: env('GRPC_HOST', '0.0.0.0'),
      port: env<int>('GRPC_PORT', 50051),
      autoStart: true,
    ),
  ),
];
```

`autoStart: true` brings the gRPC server up when the app boots.

## Define a service

Services are standard `grpc` `Service` classes. Register each method and delegate to your own logic:

```dart
import 'package:vania_grpc/vania_grpc.dart';

class GreeterService extends Service {
  GreeterService() {
    $addMethod(ServiceMethod<HelloRequest, HelloResponse>(
      'SayHello', sayHello, false, false,
      HelloRequest.fromBuffer,
      (r) => r.writeToBuffer(),
    ));
  }

  @override
  String get $name => 'greeter.Greeter';

  Future<HelloResponse> sayHello(ServiceCall call, Future<HelloRequest> request) async {
    final req = await request;
    return HelloResponse(message: 'Hello, ${req.name}!');
  }
}
```

In a real project you generate the message classes from a `.proto` file with `protoc`; the service wiring stays the same.

## Call it

```bash
grpcurl -plaintext -d '{"name":"Vania"}' \
  localhost:50051 greeter.Greeter/SayHello
```

## Good to know

- The gRPC server runs on its own port (`GRPC_PORT`, default `50051`) next to your HTTP app.
- Supports unary and streaming methods — set the streaming flags on `ServiceMethod`.
- Keep your business rules in plain functions and let the service method be a thin wrapper; it stays easy to test.

## Links

- Documentation: [vdart.dev/docs](https://vdart.dev/docs/intro)
- Source & issues: [github.com/vania-dart/framework](https://github.com/vania-dart/framework)

## License

MIT
