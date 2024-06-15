// ignore_for_file: constant_identifier_names

import 'package:vania/src/redis/exception.dart';

/// Redis error reply
class RedisError {
  final String prefix;
  final String message;

  RedisError({required this.prefix, required this.message});

  @override
  String toString() => '$prefix: $message';
}

/// Redis protocol type
enum RespType {
  STRING,
  ARRAY,
  INTEGER,
  DOUBLE,
  ERROR,
  NULL,
  UNKNOWN,
}

/// Redis protocol data
class Resp {
  static const _CRLF = '\u000d\u000a';

  final dynamic value;

  Resp(this.value);

  /// serialize value implementation
  String _serializeValue(dynamic value, {bool isBulkString = true}) {
    if (value is String) {
      if (!isBulkString && !value.contains(RegExp('s'))) {
        return '+$value$_CRLF';
      }
      return '\$${value.length}$_CRLF$value$_CRLF';
    }
    if (value is int) {
      return ':$value$_CRLF';
    }

    if (value is List) {
      final data = [
        '*${value.length}$_CRLF',
        ...value.map((e) => _serializeValue(e, isBulkString: true))
      ].join('');
      return data;
    }
    return '';
  }

  /// serialize value in this instance
  String serialize() => _serializeValue(value);

  /// deserialize and create [Resp]'s instance.
  /// [s]: serialized data
  static Resp? deserialize(String s) =>
      _deserializeEntry(s.split(_CRLF), 0)?.resp;

  /// type of [value]
  RespType get type {
    if (value == null) {
      return RespType.NULL;
    }
    if (value is String) {
      return RespType.STRING;
    }
    if (value is List) {
      return RespType.ARRAY;
    }
    if (value is int) {
      return RespType.INTEGER;
    }
    if (value is double) {
      return RespType.DOUBLE;
    }
    if (value is RedisError) {
      return RespType.ERROR;
    }
    return RespType.UNKNOWN;
  }

  /// is [type] == [RespType.NULL]
  bool get isNull => type == RespType.NULL;

  /// is [type] == [RespType.STRING]
  bool get isString => type == RespType.STRING;

  /// is [type] == [RespType.ARRAY]
  bool get isList => type == RespType.ARRAY;

  /// is [type] == [RespType.INTEGER]
  bool get isInteger => type == RespType.INTEGER;

  /// is [type] == [RespType.DOUBLE]
  bool get isDouble => type == RespType.DOUBLE;

  /// is [type] == [RespType.ERROR]
  bool get isError => type == RespType.ERROR;

  /// Get String value if [isString] == true
  String? get stringValue => isString ? value as String : null;

  /// Get List value if [isList] == true
  List<dynamic>? get arrayValue => isList ? value as List : null;

  /// Get int value if [isInteger] == true
  int? get integerValue => isInteger ? value as int : null;

  double? get doubleValue => isInteger ? value as double : null;

  /// Get [RedisError] value if [isError] == true
  RedisError? get errorValue => isError ? value as RedisError : null;

  /// throw exception if [isError] == true
  void throwIfError() {
    final err = errorValue;
    if (err == null) {
      return;
    }
    throw RedisException('$err');
  }

  /// for debug
  @override
  String toString() =>
      '$type $stringValue $arrayValue $integerValue $doubleValue $errorValue';
}

class _DeserializeResult {
  final int endIndex;
  final dynamic value;

  _DeserializeResult(this.endIndex, this.value);

  Resp get resp => Resp(value);
}

extension _SafeAt on List<String> {
  String? safeAt(int index) => index < length ? this[index] : null;
}

extension _ToInt on String {
  int? toInt() => int.tryParse(this);
}

_DeserializeResult? _deserializeEntry(List<String> s, int startIndex) {
  final current = s.safeAt(startIndex);
  if (current == null) {
    return null;
  }

  switch (current[0]) {
    case '+': // simple strings
      return _deserializeSimpleString(s, startIndex);
    case '-': // errors
      return _deserializeError(s, startIndex);
    case ':': // integers
      return _deserializeInteger(s, startIndex);
    case '\$': // bulk strings
      return _deserializeBulkString(s, startIndex);
    case '*': // arrays
      return _deserializeArray(s, startIndex);
  }

  return null;
}

_DeserializeResult? _deserializeSimpleString(List<String> s, int startIndex) {
  final value = s.safeAt(startIndex)?.substring(1);
  if (value == null) {
    return null;
  }
  return _DeserializeResult(startIndex + 1, value);
}

_DeserializeResult? _deserializeBulkString(List<String> s, int startIndex) {
  final lengthStr = s.safeAt(startIndex);
  if (lengthStr == null) {
    return null;
  }

  final length = lengthStr.substring(1).toInt();

  if (length == null) {
    return null;
  }
  if (length == -1) {
    return _DeserializeResult(startIndex + 1, null);
  }
  if (length < 0) {
    return null;
  }
  final value = s.sublist(startIndex + 1).join(Resp._CRLF).substring(0, length);

  return _DeserializeResult(
    startIndex + value.split(Resp._CRLF).length + 1,
    value,
  );
}

_DeserializeResult? _deserializeError(List<String> s, int startIndex) {
  final value = s.safeAt(startIndex)?.substring(1);
  if (value == null) {
    return null;
  }
  final spl = value.split(' ');
  final prefix = spl[0];
  final message = spl.sublist(1).join(' ');

  return _DeserializeResult(
    startIndex + 1,
    RedisError(
      prefix: prefix,
      message: message,
    ),
  );
}

_DeserializeResult? _deserializeInteger(List<String> s, int startIndex) {
  final value = s.safeAt(startIndex)?.substring(1).toInt();
  if (value == null) {
    return null;
  }
  return _DeserializeResult(startIndex + 1, value);
}

_DeserializeResult? _deserializeArray(List<String> s, int startIndex) {
  final lengthStr = s.safeAt(startIndex);
  if (lengthStr == null) {
    return null;
  }

  final length = lengthStr.substring(1).toInt();

  if (length == null) {
    return null;
  }
  if (length == -1) {
    return _DeserializeResult(startIndex + 1, null);
  }
  if (length < 0) {
    return null;
  }
  final list = [];
  var index = startIndex + 1;
  for (var i = 0; i < length; ++i) {
    final res = _deserializeEntry(s, index);
    if (res == null) {
      return null;
    }
    list.add(res.value);
    index = res.endIndex;
  }

  return _DeserializeResult(index, list);
}
