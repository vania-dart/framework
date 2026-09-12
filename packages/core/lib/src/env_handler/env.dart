import 'dart:convert';
import 'dart:io';

/// Environment variables loaded from `.env`, layered over
/// `Platform.environment`.
class Env {
  static final Env _singleton = Env._internal();

  factory Env() {
    return _singleton;
  }

  Map<String, String> env = <String, String>{};

  Env._internal();

  void load({File? file}) {
    if (env.isEmpty) {
      env = _loadEnvFile(file: file);
    }
  }

  /// get env value
  /// ```
  /// Evn.get('APP_KEY');
  /// Evn.get('APP_KEY', 'Default Value');
  /// Evn.get<int>('PORT', 3000);
  /// Evn.get<num>('PORT', 3000);
  /// Evn.get<String>('APP_KEY');
  /// ```
  static T get<T>(String key, [dynamic defaultValue]) {
    dynamic value = Env().env[key];
    value ??= Platform.environment[key];
    value ??= defaultValue;
    if (T.toString() == 'int') {
      return int.parse(value.toString()) as T;
    }

    if (T.toString() == 'double') {
      return double.parse(value.toString()) as T;
    }

    if (T.toString() == 'num') {
      return num.parse(value.toString()) as T;
    }

    if (T.toString() == 'bool') {
      return bool.parse(value.toString()) as T;
    }

    return value;
  }

  /// Loads and parses the project's `.env` file.
  ///
  /// Follows the usual dotenv rules:
  ///
  ///   * `#` starts a comment, unless it is inside a quoted value;
  ///   * single-quoted values are literal;
  ///   * double-quoted values support `\n`, `\t`, `\"` and `\\`
  ///     escapes and may span multiple lines;
  ///   * an `export ` prefix on the key is ignored;
  ///   * everything after the first `=` is the value, so values may
  ///     themselves contain `=`.
  Map<String, String> _loadEnvFile({File? file}) {
    final data = <String, String>{};

    final envFile = file ?? File('.env');
    if (!envFile.existsSync()) return data;

    final lines = const LineSplitter().convert(envFile.readAsStringSync());

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];

      final trimmed = line.trimLeft();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final separator = line.indexOf('=');
      if (separator <= 0) continue;

      var key = line.substring(0, separator).trim();
      if (key.startsWith('export ')) key = key.substring(7).trim();
      if (key.isEmpty) continue;

      var rest = line.substring(separator + 1).trimLeft();

      // A value opening with a quote may continue over several lines;
      // consume until the matching close quote.
      if (rest.startsWith('"') || rest.startsWith("'")) {
        final quote = rest[0];
        final buffer = StringBuffer();
        var remainder = rest.substring(1);
        var closed = false;

        while (true) {
          final closeIndex = _indexOfClosingQuote(remainder, quote);
          if (closeIndex != -1) {
            buffer.write(remainder.substring(0, closeIndex));
            closed = true;
            break;
          }
          buffer.write(remainder);
          if (i + 1 >= lines.length) break;
          buffer.write('\n');
          remainder = lines[++i];
        }

        var value = buffer.toString();
        // Only double quotes process escapes, matching shell semantics.
        if (quote == '"') value = _unescape(value);
        data[key] = closed ? value : value.trim();
        continue;
      }

      // Unquoted: strip a trailing inline comment, then trim.
      final commentIndex = rest.indexOf(' #');
      if (commentIndex != -1) rest = rest.substring(0, commentIndex);
      data[key] = rest.trim();
    }

    return data;
  }

  /// Index of the next [quote] not preceded by a backslash, or -1.
  int _indexOfClosingQuote(String input, String quote) {
    for (var i = 0; i < input.length; i++) {
      if (input[i] != quote) continue;
      var backslashes = 0;
      for (var j = i - 1; j >= 0 && input[j] == r'\'; j--) {
        backslashes++;
      }
      if (backslashes.isEven) return i;
    }
    return -1;
  }

  String _unescape(String value) {
    final out = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      if (value[i] != r'\' || i + 1 >= value.length) {
        out.write(value[i]);
        continue;
      }
      final next = value[++i];
      switch (next) {
        case 'n':
          out.write('\n');
        case 't':
          out.write('\t');
        case 'r':
          out.write('\r');
        case '"':
          out.write('"');
        case r'\':
          out.write(r'\');
        default:
          out
            ..write(r'\')
            ..write(next);
      }
    }
    return out.toString();
  }
}
