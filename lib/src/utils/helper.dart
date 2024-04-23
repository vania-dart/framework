import 'dart:io';

import 'package:eloquent/eloquent.dart';
import 'package:vania/vania.dart';

String storagePath(String file) => '${Directory.current.path}/storage/$file';

String publicPath(String file) => '${Directory.current.path}/public/$file';

T env<T>(String key, [dynamic defaultValue]) => Env.get<T>(key, defaultValue);

abort(int code, String message) {
  throw HttpResponseException(message: message, code: code);
}

Connection get connection => Config().get('database')?.driver?.connection;
