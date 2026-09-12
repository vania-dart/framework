import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/env.dart';

/// Parsing rules for `.env`: comments, quoting, escapes, multi-line
/// values and values that themselves contain `=`.
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('vania_env_test');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
    Env().env = <String, String>{};
  });

  /// Writes [contents] to a temp .env, loads it, and returns the map.
  Map<String, String> parse(String contents) {
    final file = File('${tmp.path}/.env')..writeAsStringSync(contents);
    Env().env = <String, String>{};
    Env().load(file: file);
    return Env().env;
  }

  test('parses plain key/value pairs', () {
    final env = parse('APP_NAME=Vania\nAPP_PORT=8080\n');
    expect(env['APP_NAME'], equals('Vania'));
    expect(env['APP_PORT'], equals('8080'));
  });

  test('ignores comments and blank lines', () {
    final env = parse('''
# this is a comment
   # indented comment

APP_NAME=Vania
''');
    expect(env['APP_NAME'], equals('Vania'));
    expect(env.containsKey('# this is a comment'), isFalse);
    expect(env.length, equals(1));
  });

  test('strips an inline comment from an unquoted value', () {
    expect(parse('APP_PORT=8080 # the http port')['APP_PORT'], equals('8080'));
  });

  test('keeps a # that is part of the value', () {
    expect(parse('COLOR=#ff0000')['COLOR'], equals('#ff0000'));
  });

  group('quoting', () {
    test('preserves quotes inside a quoted value', () {
      expect(
        parse("""PASSWORD="p'a's'sword" """)['PASSWORD'],
        equals("p'a's'sword"),
      );
    });

    test('single quotes are literal', () {
      expect(parse(r"KEY='raw \n stays'")['KEY'], equals(r'raw \n stays'));
    });

    test('double quotes process escapes', () {
      expect(parse(r'KEY="line1\nline2"')['KEY'], equals('line1\nline2'));
      expect(parse(r'KEY="a\"b"')['KEY'], equals('a"b'));
    });

    test('surrounding quotes are removed', () {
      expect(parse('KEY="value"')['KEY'], equals('value'));
    });
  });

  test('supports values containing =', () {
    expect(
      parse('URL=postgres://u:p@h/db?x=1&y=2')['URL'],
      equals('postgres://u:p@h/db?x=1&y=2'),
    );
  });

  test('supports multi-line quoted values', () {
    final env = parse('''
PRIVATE_KEY="-----BEGIN KEY-----
abc
def
-----END KEY-----"
APP_NAME=Vania
''');
    expect(env['PRIVATE_KEY'], contains('BEGIN KEY'));
    expect(env['PRIVATE_KEY'], contains('\nabc\ndef\n'));
    expect(
      env['APP_NAME'],
      equals('Vania'),
      reason: 'parsing must resume after the multi-line value',
    );
  });

  test('ignores an export prefix', () {
    expect(parse('export APP_NAME=Vania')['APP_NAME'], equals('Vania'));
  });

  test('skips malformed lines instead of throwing', () {
    final env = parse('NOT_A_PAIR\n=novalue\nGOOD=yes\n');
    expect(env['GOOD'], equals('yes'));
    expect(env.containsKey('NOT_A_PAIR'), isFalse);
  });

  test('an empty value stays empty', () {
    expect(parse('EMPTY=\nNEXT=1')['EMPTY'], equals(''));
  });
}
