import 'dart:convert';

abstract class RedisConverter<S, D> extends Converter<S, D> {
  bool isSupporting<U>(dynamic value) => value is S && U == D;
}

typedef RedisEncoder<T> = RedisConverter<T, String>;
typedef RedisDecoder<T> = RedisConverter<String, T>;

class RedisCodec<T> {
  const RedisCodec({required this.encoder, required this.decoder});

  final RedisEncoder<T> encoder;
  final RedisDecoder<T> decoder;
}

class StringEncoder extends RedisEncoder<String> {
  @override
  String convert(String input) => input;
}

class StringDecoder extends RedisDecoder<String> {
  @override
  String convert(String input) => input;
}

class IntEncoder extends RedisEncoder<int> {
  @override
  String convert(int input) => input.toString();
}

class IntDecoder extends RedisDecoder<int> {
  @override
  int convert(String input) => int.parse(input);
}

class DoubleEncoder extends RedisEncoder<double> {
  @override
  String convert(double input) => input.toString();
}

class DoubleDecoder extends RedisDecoder<double> {
  @override
  double convert(String input) => double.parse(input);
}

class JsonEncoderCodec extends RedisEncoder<Object> {
  @override
  String convert(Object input) => jsonEncode(input);
}
