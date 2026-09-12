/// Migrations and seeders must not run against a staging or production
/// database unless the operator passes `--force`.
library;

import 'package:test/test.dart';
import 'package:vania/database.dart';
import 'package:vania/foundation.dart'
    show AppEnvironment, DatabaseException, Env;

void main() {
  tearDown(() => Env().env.remove('APP_ENV'));

  group('AppEnvironment.current', () {
    test('maps the documented modes and their aliases', () {
      const cases = {
        'local': AppEnvironment.local,
        'development': AppEnvironment.local,
        'staging': AppEnvironment.staging,
        'production': AppEnvironment.production,
        'PRODUCTION': AppEnvironment.production,
      };

      cases.forEach((value, expected) {
        Env().env['APP_ENV'] = value;
        expect(AppEnvironment.current(), expected, reason: value);
      });
    });

    test('falls back to production for an unset or unknown value', () {
      Env().env['APP_ENV'] = 'whatever';
      expect(AppEnvironment.current(), AppEnvironment.production);
    });
  });

  group('guardEnvironment', () {
    test('allows the command locally', () {
      Env().env['APP_ENV'] = 'local';

      expect(() => guardEnvironment('migrate', force: false), returnsNormally);
    });

    test('refuses on production and names the environment', () {
      Env().env['APP_ENV'] = 'production';

      expect(
        () => guardEnvironment('migrate', force: false),
        throwsA(
          isA<DatabaseException>().having(
            (e) => e.message,
            'message',
            allOf(contains('production'), contains('--force')),
          ),
        ),
      );
    });

    test('refuses on staging too', () {
      Env().env['APP_ENV'] = 'staging';

      expect(
        () => guardEnvironment('migrate', force: false),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('runs on production when forced', () {
      Env().env['APP_ENV'] = 'production';

      expect(() => guardEnvironment('migrate', force: true), returnsNormally);
    });
  });
}
