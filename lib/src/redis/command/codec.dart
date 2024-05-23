import 'dart:convert';

/// converter base class
/// convert [S] to [D]
abstract class RedisConverter<S, D> extends Converter<S, D> {
  bool isSupporting<U>(dynamic value) => value is S && U == D;
}

/// convert to String from [T]
typedef RedisEncoder<T> = RedisConverter<T, String>;

/// convert to [T] from String
typedef RedisDecoder<T> = RedisConverter<String, T>;

/// encoder and decoder pair
class RedisCodec<T> {
  final RedisEncoder<T> encoder;
  final RedisDecoder<T> decoder;

  RedisCodec({
    required this.encoder,
    required this.decoder,
  });
}

/// builtin String to String encoder
class StringEncoder extends RedisEncoder<String> {
  @override
  String convert(String input) => input;
}

/// builtin String to String decoder
class StringDecoder extends RedisDecoder<String> {
  @override
  String convert(String input) => input;
}

/// builtin int to String encoder
class IntEncoder extends RedisEncoder<int> {
  @override
  String convert(int input) => input.toString();
}

/// builtin String to int decoder
class IntDecoder extends RedisDecoder<int> {
  @override
  int convert(String input) => int.parse(input);
}
