import 'dart:async';

import 'package:grpc/grpc.dart';
import 'package:vania/foundation.dart' show Logger;

class GrpcExceptionInterceptor extends ServerInterceptor {
  GrpcExceptionInterceptor({this.debug = false});

  final bool debug;

  @override
  Stream<R> intercept<Q, R>(
    ServiceCall call,
    ServiceMethod<Q, R> method,
    Stream<Q> requests,
    ServerStreamingInvoker<Q, R> invoker,
  ) {
    try {
      return invoker(call, method, requests).handleError((error) {
        if (error is GrpcError) throw error;
        Logger.log(
          'gRPC ${method.name} failed: $error',
          type: Logger.ERROR,
          fileName: 'grpc',
        );
        throw GrpcError.internal(debug ? error.toString() : 'Internal error');
      });
    } on GrpcError {
      rethrow;
    } catch (error) {
      Logger.log(
        'gRPC ${method.name} failed: $error',
        type: Logger.ERROR,
        fileName: 'grpc',
      );
      throw GrpcError.internal(debug ? error.toString() : 'Internal error');
    }
  }
}

FutureOr<GrpcError?> grpcMetadataGuard(
  ServiceCall call,
  ServiceMethod method, {
  required bool Function(Map<String, String> metadata) authorize,
  String message = 'Unauthenticated',
}) {
  return authorize(call.clientMetadata ?? const {})
      ? null
      : GrpcError.unauthenticated(message);
}
