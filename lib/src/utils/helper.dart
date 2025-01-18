import 'dart:io';
import 'package:vania/src/localization_handler/localization.dart';
import 'package:vania/vania.dart';

import '../http/session/session_manager.dart';
import '../view_engine/template_engine.dart';

String storagePath(String file) => 'storage/$file';

String publicPath(String file) => 'public/$file';

String url(String path) => '${env<String>('APP_URL')}/$path';

String assets(String src) => url(src);

bool can(String ability) => Gate().allows(ability);

bool cannot(String ability) => Gate().denies(ability);

T env<T>(String key, [dynamic defaultValue]) => Env.get<T>(key, defaultValue);

String trans(
  String key, [
  Map<String, dynamic>? args,
]) =>
    Localization().trans(
      key,
      args,
    );

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

Response view(String template, [Map<String, dynamic>? context]) =>
    Response.html(TemplateEngine().render(template, context));

Future<void> setSession(String key, dynamic value) async =>
    await SessionManager().setSession(key, value);
Future<T> getSession<T>(String key) async =>
    TemplateEngine().sessions[key] ?? await SessionManager().getSession<T>(key);
Future<Map<String, dynamic>?> allSessions() async =>
    await SessionManager().allSessions();
Future<void> deleteSession(String key) async =>
    await SessionManager().deleteSession(key);
Future<void> destroyAllSessions() async =>
    await SessionManager().destroyAllSessions();
