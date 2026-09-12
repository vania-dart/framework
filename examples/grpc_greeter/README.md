# gRPC Greeter Example

A minimal gRPC service built with [`vania_grpc`](../../packages/vania_grpc)
and the [Vania](../../packages/core) framework:

```proto
service greeter.Greeter {
  rpc SayHello (HelloRequest) returns (HelloResponse);
}
message HelloRequest  { string name = 1; }
message HelloResponse { string message = 1; }
```

## How it works

- [hello_messages.dart](lib/greeter/hello_messages.dart) — the request/response
  messages, with the protobuf wire encoding written by hand (single string
  field) so the example needs **no `.proto` codegen**. A real project would
  generate these with `protoc`.
- [greeter_service.dart](lib/greeter/greeter_service.dart) — a `grpc` `Service`
  that registers the unary `SayHello` method; the greeting rule is the pure
  function `greetingFor`.
- [config/app.dart](lib/config/app.dart) — `GrpcServiceProvider(services:
  [GreeterService()], config: GrpcConfig(..., autoStart: true))`.

## Running

```bash
dart pub get
dart run bin/server.dart
```

The gRPC server listens on `GRPC_PORT` (default `50051`); the Vania HTTP
server also starts on `APP_PORT` (8000). Call it with any gRPC client, e.g.
[`grpcurl`](https://github.com/fullstorydev/grpcurl):

```bash
grpcurl -plaintext -d '{"name":"Vania"}' \
  localhost:50051 greeter.Greeter/SayHello
# { "message": "Hello, Vania!" }
```

(Reflection isn't enabled, so pass the method name explicitly as above.)

## Tests

No server needed — the message codec round-trips, the greeting rule, and the
`SayHello` handler (invoked directly) are all tested in-process:

```bash
dart test
```
