---
sidebar_position: 8
---

# gRPC (vania_grpc)

The `vania_grpc` package runs a gRPC server alongside your Vania HTTP server. It supports service registration, interceptors, health checking, and TLS.

## Installation

```yaml
dependencies:
  vania_grpc: ^1.0.0
  grpc: ^4.0.0
  protobuf: ^3.0.0
```

## Setup

### 1. Define Your Protobuf Services

Create `.proto` files and generate Dart code with `protoc`:

```protobuf
// protos/greeter.proto
syntax = "proto3";
package greeter;

service Greeter {
  rpc SayHello (HelloRequest) returns (HelloReply);
}

message HelloRequest {
  string name = 1;
}

message HelloReply {
  string message = 1;
}
```

Generate:

```bash
protoc --dart_out=grpc:lib/src/generated protos/greeter.proto
```

### 2. Implement the Service

```dart
import 'package:grpc/grpc.dart';
import 'package:my_app/src/generated/greeter.pbgrpc.dart';

class GreeterService extends GreeterServiceBase {
  @override
  Future<HelloReply> sayHello(ServiceCall call, HelloRequest request) async {
    return HelloReply()..message = 'Hello, ${request.name}!';
  }
}
```

### 3. Register the Provider

```dart
import 'package:vania_grpc/vania_grpc.dart';

'providers': [
  RouteServiceProvider(),
  GrpcServiceProvider(services: [GreeterService()]),
],
```

Or register and start manually:

```dart
VaniaGrpcServer().register(GreeterService());
await VaniaGrpcServer().serve();
```

## Configuration

```dart
GrpcServiceProvider(
  services: [GreeterService(), UserService()],
  config: GrpcConfig(
    host: '0.0.0.0',
    port: 50051,
    autoStart: true,
    healthEnabled: true,
  ),
);
```

Via `.env`:

```env
GRPC_HOST=0.0.0.0
GRPC_PORT=50051
GRPC_ENABLED=true
GRPC_AUTO_START=true
```

## Interceptors

### Logging Interceptor

Logs every gRPC call with method name and duration:

```dart
VaniaGrpcServer().addServerInterceptor(GrpcLoggingInterceptor());
```

### Exception Interceptor

Catches non-gRPC exceptions and wraps them in `GrpcError.internal`:

```dart
VaniaGrpcServer().addServerInterceptor(GrpcExceptionInterceptor());
```

### Metadata (Auth) Interceptor

Validates client-provided metadata (e.g., API keys or tokens):

```dart
VaniaGrpcServer().addInterceptor(GrpcMetadataInterceptor());
```

### Custom Interceptor

```dart
class RateLimitInterceptor implements ServerInterceptor {
  @override
  Future<GrpcError?> call(ServiceCall call, ServiceMethod method) async {
    // Your logic here
    return null; // return null to allow, or GrpcError to reject
  }
}

VaniaGrpcServer().addServerInterceptor(RateLimitInterceptor());
```

## Health Checking

When `healthEnabled` is `true`, the server exposes the standard gRPC Health Checking Protocol:

```dart
// Set service health status
VaniaGrpcServer().setHealthStatus('greeter.Greeter', ServingStatus.serving);
```

Clients can check health with the standard `grpc.health.v1.Health/Check` RPC.

## TLS

```dart
GrpcConfig(
  secure: true,
  certificatePath: 'certs/server.crt',
  privateKeyPath: 'certs/server.key',
);
```

## Client Factory

Create client channels to call other gRPC services:

```dart
import 'package:vania_grpc/vania_grpc.dart';

// Insecure channel
var channel = GrpcClientFactory.insecure('localhost', port: 50051);

// With config
var channel = GrpcClientFactory.channel(GrpcClientConfig(
  host: 'api.example.com',
  port: 443,
  secure: true,
));

// Use with generated client
var client = GreeterClient(channel);
var response = await client.sayHello(HelloRequest()..name = 'Alice');
print(response.message);
```

## Server Lifecycle

```dart
// Check if running
bool running = VaniaGrpcServer().isRunning;

// Get port
int port = VaniaGrpcServer().port;

// Graceful shutdown
await VaniaGrpcServer().shutdown();
```
