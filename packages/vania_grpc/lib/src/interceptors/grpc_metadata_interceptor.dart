import 'dart:async';

import 'package:grpc/grpc.dart';

typedef GrpcMetadataAuthorizer = bool Function(Map<String, String> metadata);

class GrpcMetadataInterceptor {
  const GrpcMetadataInterceptor({
    required this.authorize,
    this.errorMessage = 'Unauthenticated',
  });

  final GrpcMetadataAuthorizer authorize;
  final String errorMessage;

  FutureOr<GrpcError?> call(ServiceCall call, ServiceMethod method) {
    final metadata = call.clientMetadata ?? const <String, String>{};
    if (authorize(metadata)) return null;
    return GrpcError.unauthenticated(errorMessage);
  }
}
