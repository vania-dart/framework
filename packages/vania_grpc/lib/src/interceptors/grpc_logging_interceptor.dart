import 'dart:async';

import 'package:grpc/grpc.dart';
import 'package:vania/foundation.dart' show Logger;

class GrpcLoggingInterceptor extends ServerInterceptor {
  GrpcLoggingInterceptor({this.fileName = 'grpc'});

  final String fileName;

  @override
  Stream<R> intercept<Q, R>(
    ServiceCall call,
    ServiceMethod<Q, R> method,
    Stream<Q> requests,
    ServerStreamingInvoker<Q, R> invoker,
  ) {
    final startedAt = DateTime.now();
    Logger.log('gRPC ${method.name} started', fileName: fileName);
    return invoker(call, method, requests).transform(
      StreamTransformer.fromHandlers(
        handleDone: (sink) {
          final elapsed = DateTime.now().difference(startedAt);
          Logger.log(
            'gRPC ${method.name} completed in ${elapsed.inMilliseconds}ms',
            fileName: fileName,
          );
          sink.close();
        },
        handleError: (error, stackTrace, sink) {
          final elapsed = DateTime.now().difference(startedAt);
          Logger.log(
            'gRPC ${method.name} failed in ${elapsed.inMilliseconds}ms: $error',
            type: Logger.ERROR,
            fileName: fileName,
          );
          sink.addError(error, stackTrace);
        },
      ),
    );
  }
}
