class RedisException implements Exception {
  const RedisException(this.message);

  final String message;

  @override
  String toString() => 'RedisException: $message';
}

class RedisConvertException extends RedisException {
  const RedisConvertException(String message)
    : super('convert error: $message');
}
