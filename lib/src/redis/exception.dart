/// Redis error exception class
/// All exceptions thrown from this package inherit from this class.
class RedisException implements Exception {
  final String message;

  const RedisException(this.message);

  @override
  String toString() => 'RedisException: $message';
}

/// Convert error exception class
class RedisConvertException extends RedisException {
  const RedisConvertException(String message)
      : super('convert error: $message');
}
