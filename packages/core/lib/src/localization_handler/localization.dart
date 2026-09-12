import 'dart:convert';
import 'package:vania/src/ioc_container.dart';
import 'dart:io';
import 'package:vania/env.dart' show env;

class Localization {
  Localization.createDefault();

  factory Localization() =>
      IoCContainer().resolveOrDefault<Localization>(Localization.createDefault);

  String? _locale = env('APP_LOCALE');

  final Map<String, dynamic> _language = {};

  void setLocale(String locale) => _locale = locale;

  bool isLocale(String locale) => _locale == locale;

  /// Loads all `<locale>/*.json` bundles under `APP_LANG_PATH` (default `lib/lang`).
  Future<void> init() async {
    final Directory languagePath = Directory(env('APP_LANG_PATH', 'lib/lang'));
    if (!languagePath.existsSync()) return;

    // Reset in case init() is called multiple times (tests, hot restart).
    _language.clear();

    for (final entity in languagePath.listSync(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! Directory) continue;
      final segments = entity.uri.pathSegments.where((s) => s.isNotEmpty);
      final subdirName = segments.last.toLowerCase();
      final fileMap = <String, dynamic>{};
      for (final file
          in entity
              .listSync(recursive: false)
              .whereType<File>()
              .where((f) => f.path.toLowerCase().endsWith('.json'))) {
        try {
          final content = file.readAsStringSync();
          final decoded = json.decode(content);
          if (decoded is Map<String, dynamic>) fileMap.addAll(decoded);
        } catch (e) {
          stderr.writeln('⚠️ Failed to parse ${file.path}: $e');
        }
      }
      _language[subdirName] = fileMap;
    }
  }

  /// Translates a string based on the provided key and optional arguments.
  String trans(String key, [Map<String, dynamic>? args, String? locale]) {
    final effective = locale ?? _locale;
    Map<String, dynamic> bundle = _language[effective] ?? const {};
    if (!bundle.containsKey(key)) {
      // Try default locale if we were asked for a specific override.
      if (effective != _locale) {
        bundle = _language[_locale] ?? const {};
      }
      if (!bundle.containsKey(key)) {
        return 'Translation not found for key: $key';
      }
    }

    String tmp = bundle[key].toString();
    if (args == null || args.isEmpty) return tmp;
    args.forEach((placeholder, value) {
      tmp = tmp.replaceAll('{$placeholder}', value.toString());
    });
    return tmp;
  }
}
