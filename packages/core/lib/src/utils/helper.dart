import 'package:vania/src/authentication/gate/gate.dart';
import 'package:vania/src/http/session/flash_messages.dart';
import 'package:vania/env.dart';
import 'package:vania/src/exception/http_exception.dart';

import 'package:vania/src/ioc_container.dart';
import 'package:vania/src/localization_handler/localization.dart';

import '../http/session/session_manager.dart';
import '../http/validation/field_validation.dart';

String storagePath(String file) => 'storage/$file';

String publicPath(String file) => 'public/$file';

String url(String path) => '${env<String>('APP_URL')}/$path';

String assets(String src) => url(src);

FieldValidation field(String fieldName) => FieldValidation(fieldName);

bool can(String ability) => Gate().allows(ability);

bool cannot(String ability) => Gate().denies(ability);

String trans(String key, {Map<String, dynamic>? args, String? locale}) =>
    Localization().trans(key, args, locale);
void setLocale(String locale) => Localization().setLocale(locale);
bool isLocale(String locale) => Localization().isLocale(locale);

void abort(int code, String message) {
  throw HttpResponseException(message: message, code: code);
}

Future<void> setSession(String key, dynamic value) async =>
    await IoCContainer().resolve<SessionManager>().setSession(key, value);
Future<T> getSession<T>(String key) async =>
    FlashMessages().message(key) ??
    await IoCContainer().resolve<SessionManager>().getSession<T>(key);
Future<Map<String, dynamic>?> allSessions() async =>
    IoCContainer().resolve<SessionManager>().allSessions;
Future<void> deleteSession(String key) async =>
    await IoCContainer().resolve<SessionManager>().deleteSession(key);
Future<void> destroyAllSessions() async =>
    await IoCContainer().resolve<SessionManager>().destroyAllSessions();
