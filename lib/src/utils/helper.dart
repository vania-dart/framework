import 'package:eloquent/eloquent.dart';
import 'package:vania/src/database/database_client.dart';
import 'package:vania/vania.dart';

String storagePath(String file) => 'storage/$file';

String publicPath(String file) => 'public/$file';

T env<T>(String key, [dynamic defaultValue]) => Env.get<T>(key, defaultValue);

abort(int code, String message) {
  throw HttpResponseException(message: message, code: code);
}

Connection? get connection => DatabaseClient().database?.connection;
