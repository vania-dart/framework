import 'dart:io';

/// Consistent terminal output with automatic colour detection.
abstract final class Console {
  static final bool _usesColor =
      stdout.hasTerminal && !Platform.environment.containsKey('NO_COLOR');

  static String _wrap(String code, String value) =>
      _usesColor ? '\x1B[${code}m$value\x1B[0m' : value;

  static String bold(String value) => _wrap('1', value);
  static String dim(String value) => _wrap('2', value);
  static String red(String value) => _wrap('31', value);
  static String green(String value) => _wrap('32', value);
  static String yellow(String value) => _wrap('33', value);
  static String blue(String value) => _wrap('34', value);
  static String magenta(String value) => _wrap('35', value);
  static String cyan(String value) => _wrap('36', value);

  static void line([String value = '']) => stdout.writeln(value);
  static void info(String value) => stdout.writeln(value);
  static void success(String value) => stdout.writeln('${green('✓')} $value');
  static void warn(String value) => stderr.writeln('${yellow('!')} $value');
  static void error(String value) => stderr.writeln('${red('✗')} $value');

  static void clear() {
    if (_usesColor) stdout.write('\x1B[2J\x1B[H');
  }

  static void table(
    List<String> headers,
    List<List<String>> rows, {
    String Function(int column, String value)? colorize,
  }) {
    if (rows.isEmpty) return;

    final widths = List<int>.generate(headers.length, (column) {
      return <String>[
        headers[column],
        for (final row in rows)
          if (column < row.length) row[column],
      ].map((value) => value.length).reduce((a, b) => a > b ? a : b);
    });

    String render(List<String> cells, {bool header = false}) {
      return List<String>.generate(headers.length, (column) {
        final value = column < cells.length ? cells[column] : '';
        final padded = value.padRight(widths[column]);
        if (header) return bold(padded);
        return colorize?.call(column, padded) ?? padded;
      }).join('  ').trimRight();
    }

    line(render(headers, header: true));
    line(dim(widths.map((width) => '─' * width).join('  ')));
    for (final row in rows) {
      line(render(row));
    }
  }
}
