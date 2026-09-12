import 'package:vania/foundation.dart' show AppEnvironment, DatabaseException;

/// Refuses schema- or data-changing commands outside a local environment.
///
/// Migrations and seeders rewrite the database in place, so running them
/// against a staging or production `APP_ENV` has to be deliberate: pass
/// `--force` to say so.
void guardEnvironment(String command, {required bool force}) {
  final environment = AppEnvironment.current();
  if (!environment.isProtected || force) return;

  throw DatabaseException(
    'Refusing to run "$command": APP_ENV is ${environment.name}. '
    'This would change a ${environment.name} database. Re-run with --force '
    'if that is what you want.',
  );
}

/// True when `--force` was passed on the command line.
bool hasForceFlag(List<String> args) => args.contains('--force');
