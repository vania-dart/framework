import 'dart:io';
import 'package:vania/src/env_handler/env_loader_impl.dart';
import 'package:vania/src/env_handler/parser/bool_parser.dart';
import 'package:vania/src/env_handler/parser/double_parser.dart';
import 'package:vania/src/env_handler/parser/int_parser.dart';
import 'package:vania/src/env_handler/parser/num_parser.dart';
import 'package:vania/src/env_handler/parser/parser.dart';
import 'package:vania/vania.dart';

String storagePath(String file) => 'storage/$file';

String publicPath(String file) => 'public/$file';
T env<T>(String key, [dynamic defaultValue]) =>
    Env(envLoader: EnvLoader()).get<T>(key, defaultValue);

String url(String path) {
  final env = Env(envLoader: EnvLoader());
  return '${env.get<String>('APP_URL')}/$path';
}

String assets(String src) => url(src);
Map<Type, Parser> parsers = {
  int: IntParser(),
  double: DoubleParser(),
  bool: BoolParser(),
  num: NumParser(),
};

abort(int code, String message) {
  throw HttpResponseException(message: message, code: code);
}

// Databse Helper
Connection? get connection => DatabaseClient().database?.connection;

// DB Transaction
void dbTransaction(
  Future<void> Function(Connection connection) callback, [
  int? timeoutInSeconds,
]) {
  connection?.transaction(
    (con) async {
      callback(con);
    },
    timeoutInSeconds,
  ).onError((e, _) {
    throw HttpResponseException(
      message: "DbTransaction error: ${e.toString()}",
      code: HttpStatus.internalServerError,
    );
  });
}
