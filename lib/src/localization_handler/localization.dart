import 'dart:convert';
import 'dart:io';
import 'package:vania/src/utils/helper.dart' show env;

class Localization {
  static final Localization _singleton = Localization._internal();
  factory Localization() {
    return _singleton;
  }
  Localization._internal();

  String? _locale = env('APP_LOCALE');

  final Map<String, dynamic> _language = {};

  void setLocale(String locale) => _locale = locale;

  bool isLocale(String locale) => _locale == locale;

  /// Initializes the language data by loading all `.json` language files from `lib/lang` directory.
  /// - `LANG_PATH` specifies the directory where the language files are stored (defaults to `lib/lang/` if not set).
  /// - `LOCALE` specifies the language/locale to load (defaults to `en` if not set).
  void init() async {
    Directory languagePath = Directory(env('APP_LANG_PATH', 'lib/lang/'));
    for (var entity
        in languagePath.listSync(recursive: true, followLinks: false)) {
      if (entity is Directory) {
        final segments = entity.uri.pathSegments.where((s) => s.isNotEmpty);
        final subdirName = segments.last.toLowerCase();
        final fileMap = <String, dynamic>{};
        for (var file in entity
            .listSync(recursive: false)
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.json'))) {
          try {
            final content = file.readAsStringSync();
            final decoded = json.decode(content);
            fileMap.addAll(decoded);
          } catch (e) {
            stderr.writeln('⚠️ Failed to parse ${file.path}: $e');
          }
        }
        _language[subdirName] = fileMap;
      }
    }
  }

  /// Translates a string based on the provided key and optional arguments.
  String trans(String key, [Map<String, dynamic>? args, String? locale]) {
    if (!_language[locale ?? _locale].containsKey(key)) {
      return 'Translation not found for key: $key';
    }

    String tmp = _language[locale ?? _locale][key];

    if (args == null || args.isEmpty) {
      return tmp;
    }

    args.forEach((placeholder, value) {
      tmp = tmp.replaceAll('{$placeholder}', value.toString());
    });

    return tmp;
  }
}
