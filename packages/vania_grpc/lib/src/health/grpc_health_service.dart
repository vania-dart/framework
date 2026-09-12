import 'package:grpc/grpc.dart';

enum GrpcServingStatus {
  unknown(0),
  serving(1),
  notServing(2),
  serviceUnknown(3);

  const GrpcServingStatus(this.value);

  final int value;
}

class GrpcHealthCheckRequest {
  const GrpcHealthCheckRequest({this.service = ''});

  final String service;

  static GrpcHealthCheckRequest fromBuffer(List<int> bytes) {
    var index = 0;
    var service = '';
    while (index < bytes.length) {
      final tag = _readVarint(bytes, index);
      index = tag.nextIndex;
      final field = tag.value >> 3;
      final wireType = tag.value & 0x07;
      if (field == 1 && wireType == 2) {
        final length = _readVarint(bytes, index);
        index = length.nextIndex;
        service = String.fromCharCodes(
          bytes.sublist(index, index + length.value),
        );
        index += length.value;
        continue;
      }
      index = _skip(bytes, index, wireType);
    }
    return GrpcHealthCheckRequest(service: service);
  }
}

class GrpcHealthCheckResponse {
  const GrpcHealthCheckResponse({required this.status});

  final GrpcServingStatus status;

  List<int> writeToBuffer() => [0x08, ..._writeVarint(status.value)];
}

typedef GrpcHealthStatusResolver =
    GrpcServingStatus Function(String serviceName);

class GrpcHealthService extends Service {
  GrpcHealthService({
    GrpcHealthStatusResolver? resolver,
    Map<String, GrpcServingStatus> statuses = const {},
  }) : _resolver = resolver,
       _statuses = Map<String, GrpcServingStatus>.from(statuses) {
    $addMethod(
      ServiceMethod<GrpcHealthCheckRequest, GrpcHealthCheckResponse>(
        'Check',
        check,
        false,
        false,
        GrpcHealthCheckRequest.fromBuffer,
        (response) => response.writeToBuffer(),
      ),
    );
    $addMethod(
      ServiceMethod<GrpcHealthCheckRequest, GrpcHealthCheckResponse>(
        'Watch',
        watch,
        false,
        true,
        GrpcHealthCheckRequest.fromBuffer,
        (response) => response.writeToBuffer(),
      ),
    );
  }

  final GrpcHealthStatusResolver? _resolver;
  final Map<String, GrpcServingStatus> _statuses;

  @override
  String get $name => 'grpc.health.v1.Health';

  Future<GrpcHealthCheckResponse> check(
    ServiceCall call,
    Future<GrpcHealthCheckRequest> request,
  ) async {
    final resolved = await request;
    return GrpcHealthCheckResponse(status: _status(resolved.service));
  }

  Stream<GrpcHealthCheckResponse> watch(
    ServiceCall call,
    Future<GrpcHealthCheckRequest> request,
  ) async* {
    final resolved = await request;
    yield GrpcHealthCheckResponse(status: _status(resolved.service));
  }

  void setStatus(String service, GrpcServingStatus status) {
    _statuses[service] = status;
  }

  GrpcServingStatus _status(String service) {
    final custom = _resolver?.call(service);
    if (custom != null) return custom;
    return _statuses[service] ?? _statuses[''] ?? GrpcServingStatus.serving;
  }
}

class _VarintRead {
  const _VarintRead(this.value, this.nextIndex);

  final int value;
  final int nextIndex;
}

_VarintRead _readVarint(List<int> bytes, int start) {
  var result = 0;
  var shift = 0;
  var index = start;
  while (index < bytes.length) {
    final byte = bytes[index++];
    result |= (byte & 0x7f) << shift;
    if ((byte & 0x80) == 0) return _VarintRead(result, index);
    shift += 7;
  }
  return _VarintRead(result, index);
}

List<int> _writeVarint(int value) {
  final bytes = <int>[];
  var current = value;
  while (current > 0x7f) {
    bytes.add((current & 0x7f) | 0x80);
    current >>= 7;
  }
  bytes.add(current);
  return bytes;
}

int _skip(List<int> bytes, int index, int wireType) {
  if (wireType == 0) return _readVarint(bytes, index).nextIndex;
  if (wireType == 2) {
    final length = _readVarint(bytes, index);
    return length.nextIndex + length.value;
  }
  if (wireType == 5) return index + 4;
  if (wireType == 1) return index + 8;
  return bytes.length;
}
