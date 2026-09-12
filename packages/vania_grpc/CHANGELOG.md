## 1.0.0

First stable release.

- Requires `vania` 2.0.0.
- gRPC server and client integration with Vania's service providers.
- The canonical `grpc.health.v1` service ships at `proto/health.proto`, with
  `tool/generate_proto.sh` for regenerating the Dart bindings.
- `GrpcExceptionInterceptor` is not added twice when the caller already
  supplies one — the first interceptor on the list wins.
- Prevent duplicate `GrpcExceptionInterceptor` in the server chain when the
  caller adds their own — the first one on the list wins.
- Ship the canonical `grpc.health.v1` `.proto` at `proto/health.proto` plus
  `tool/generate_proto.sh` for regenerating Dart bindings.
- Real README.
