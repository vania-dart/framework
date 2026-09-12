import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/env.dart';
import 'package:vania/src/localization_handler/localization.dart';

Future<void> _setupLang(Map<String, Map<String, String>> locales) async {
  final tmp = await Directory.systemTemp.createTemp('vania_i18n_test_');
  for (final entry in locales.entries) {
    final dir = Directory('${tmp.path}/${entry.key}');
    await dir.create(recursive: true);
    final file = File('${dir.path}/messages.json');
    final buf = StringBuffer('{');
    var first = true;
    entry.value.forEach((k, v) {
      if (!first) buf.write(',');
      buf.write('"$k":"$v"');
      first = false;
    });
    buf.write('}');
    await file.writeAsString(buf.toString());
  }
  Env().env['APP_LANG_PATH'] = tmp.path;
  Env().env['APP_LOCALE'] = 'en';
  addTearDown(() async {
    await tmp.delete(recursive: true);
    Env().env.remove('APP_LANG_PATH');
    Env().env.remove('APP_LOCALE');
  });
}

void main() {
  group('Localization.init', () {
    test(
      'when init is awaited, trans() immediately after returns loaded value',
      () async {
        await _setupLang({
          'en': {'welcome': 'Welcome'},
          'es': {'welcome': 'Bienvenido'},
        });

        await Localization().init();

        expect(Localization().trans('welcome'), equals('Welcome'));
      },
    );

    test('when locale switched, trans returns other-locale string', () async {
      await _setupLang({
        'en': {'welcome': 'Welcome'},
        'es': {'welcome': 'Bienvenido'},
      });
      await Localization().init();
      Localization().setLocale('es');
      expect(Localization().trans('welcome'), equals('Bienvenido'));
      Localization().setLocale('en');
    });

    test(
      'when locale is unknown, falls back gracefully (no NoSuchMethodError)',
      () async {
        await _setupLang({
          'en': {'welcome': 'Welcome'},
        });
        await Localization().init();
        Localization().setLocale('unknown');
        expect(() => Localization().trans('welcome'), returnsNormally);
        Localization().setLocale('en');
      },
    );
  });
}
