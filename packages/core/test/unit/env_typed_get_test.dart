import 'package:test/test.dart';
import 'package:vania/env.dart';

/// Reading a typed value with `env<T>(key, default)`.
void main() {
  tearDown(
    () => Env().env
      ..remove('EMPTY')
      ..remove('BLANK')
      ..remove('SET'),
  );

  test('an empty value is no value: a typed read gets the default', () {
    // `HTTP_BACKLOG=` in a .env file, say, with nothing after the `=`.
    Env().env['EMPTY'] = '';
    Env().env['BLANK'] = '  ';
    expect(env<int>('EMPTY', 1024), 1024);
    expect(env<int>('BLANK', 7), 7);
    expect(env<double>('EMPTY', 1.5), 1.5);
    expect(env<num>('EMPTY', 2), 2);
    expect(env<bool>('EMPTY', true), isTrue);
  });

  test('an empty string is still an empty string', () {
    Env().env['EMPTY'] = '';
    expect(env<String>('EMPTY', 'default'), '');
  });

  test('a set value is read as before', () {
    Env().env['SET'] = '42';
    expect(env<int>('SET', 1), 42);
  });
}
