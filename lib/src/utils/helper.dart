import 'dart:io';
import 'package:vania/vania.dart';

String storagePath(String file) => 'storage/$file';

String publicPath(String file) => 'public/$file';

String url(String path) => '${env<String>('APP_URL')}/$path';

String assets(String src) => url(src);

T env<T>(String key, [dynamic defaultValue]) => Env.get<T>(key, defaultValue);

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
