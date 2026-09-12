import 'dart:io';

import 'package:vania/database.dart';
import 'package:vania/foundation.dart'
    show DatabaseException, toSnakeCase, QueryException;
import '../../environment_guard.dart';

class MigrationRunner {
  int? _currentBatch;
  final Map<String, Migration> _migrations = {};

  MigrationRunner migrationRegister(List<Migration> migrations) {
    _migrations.clear();
    for (var migration in migrations) {
      String name = migration.migrationName;
      if (_migrations.containsKey(name)) {
        throw DatabaseException(
          'Duplicate migration name "$name". Every migration class must '
          'produce a unique name.',
        );
      }
      _migrations[name] = migration;
    }
    return this;
  }

  Future<void> run(List<String> args) async {
    guardEnvironment(_commandName(args), force: hasForceFlag(args));
    _requireConnection();
    _currentBatch = null;

    if (args.contains('--fresh')) {
      await _fresh(_migrations);
    } else if (args.contains('--install')) {
      await _install();
    } else if (args.contains('--refresh')) {
      await _refresh(_migrations);
    } else if (args.contains('--reset')) {
      await _reset(_migrations);
    } else if (args.contains('--rollback')) {
      await _rollback(
        _migrations,
        steps: _intFlag(args, '--steps'),
        batch: _intFlag(args, '--batch'),
      );
    } else {
      for (final migration in _migrations.values) {
        await _runUp(migration.migrationName, migration.up);
      }
      stderr.writeln('✅ All migrations executed successfully!');
    }
  }

  /// The name reported when a command is refused, e.g. `migrate --fresh`.
  String _commandName(List<String> args) {
    const commands = [
      '--fresh',
      '--install',
      '--refresh',
      '--reset',
      '--rollback',
    ];
    final flag = args.firstWhere(commands.contains, orElse: () => '');
    return flag.isEmpty ? 'migrate' : 'migrate $flag';
  }

  /// Reads `--flag <int>` from [args], or null when the flag is absent.
  int? _intFlag(List<String> args, String flag) {
    final index = args.indexOf(flag);
    if (index < 0) return null;
    if (index + 1 >= args.length) {
      throw DatabaseException('Missing value for $flag');
    }
    final value = int.tryParse(args[index + 1]);
    if (value == null || value < 1) {
      throw DatabaseException(
        'Invalid value for $flag: "${args[index + 1]}" is not a positive '
        'integer.',
      );
    }
    return value;
  }

  DatabaseConnection _requireConnection() {
    final connection = MigrationConnection().connection;
    if (connection == null) {
      throw DatabaseException(
        'Database connection not established. Call '
        'MigrationConnection().setup(databaseConfig) first.',
      );
    }
    return connection;
  }

  DatabaseAdapterInterface _requireAdapter() {
    final adapter = MigrationConnection().adapter;
    if (adapter == null) {
      throw DatabaseException(
        'No migration adapter is available. Call '
        'MigrationConnection().setup(databaseConfig) first.',
      );
    }
    return adapter;
  }

  String _esc(String identifier) =>
      _requireAdapter().escapeIdentifier(identifier);

  /// The migration history table/collection, which differs per driver
  /// (MongoDB uses `_migrations`).
  String get _historyTable => _esc(_requireAdapter().migrationsTable);

  /// Driver-correct literal quoting, so migration names containing a quote
  /// cannot break — or inject into — the generated statement.
  String _literal(String value) => _requireAdapter().formatValue(value);

  Future<void> _runUp(String migrationName, Function migrationCallback) async {
    final isExecuted = await _isMigrationExecuted(migrationName);
    if (isExecuted) {
      stderr.writeln('Migration $migrationName already executed, skipping...');
      return;
    }

    final stopwatch = Stopwatch()..start();

    try {
      await migrationCallback();
      final batchNumber = await _getNextBatchNumber();
      await _recordMigrationWithBatch(migrationName, batchNumber);

      stopwatch.stop();
      stderr.writeln(
        ' Migration $migrationName executed ....................................\x1B[32m ${stopwatch.elapsedMilliseconds}ms DONE\x1B[0m',
      );
    } catch (e) {
      stopwatch.stop();
      stderr.writeln(
        '❌ Migration $migrationName failed ......................................\x1B[31m ${stopwatch.elapsedMilliseconds}ms FAILED\x1B[0m',
      );
      throw DatabaseException(
        'Migration $migrationName failed',
        e is QueryException ? e.cause : e,
      );
    }
  }

  Future<void> _runDown(
    String migrationName,
    Function migrationCallback,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      await migrationCallback();

      stopwatch.stop();
      stderr.writeln(
        ' Migration $migrationName rolled back....................................\x1B[32m ${stopwatch.elapsedMilliseconds}ms DONE\x1B[0m',
      );
    } catch (e) {
      stopwatch.stop();
      stderr.writeln(
        ' Migration $migrationName failed ......................................\x1B[31m ${stopwatch.elapsedMilliseconds}ms FAILED\x1B[0m',
      );
      throw DatabaseException(
        'Rollback of $migrationName failed',
        e is QueryException ? e.cause : e,
      );
    }
  }

  Future<bool> _isMigrationExecuted(String migrationName) async {
    final connection = _requireConnection();
    try {
      final name = _literal(toSnakeCase(migrationName));
      final result = await connection.select(
        'SELECT ${_esc("id")} FROM $_historyTable '
        'WHERE ${_esc("migration")}=$name',
      );
      return result.isNotEmpty;
    } on QueryException catch (e) {
      throw DatabaseException(
        'Failed to check if migration $migrationName is executed',
        e.cause,
      );
    }
  }

  Future<void> _recordMigrationWithBatch(
    String migrationName,
    int batch,
  ) async {
    final connection = _requireConnection();
    try {
      final name = _literal(toSnakeCase(migrationName));
      await connection.execute(
        'INSERT INTO $_historyTable '
        '(${_esc("migration")}, ${_esc("batch")}) VALUES ($name, $batch)',
      );
    } on QueryException catch (e) {
      throw DatabaseException(
        'Failed to record migration $migrationName',
        e.cause,
      );
    }
  }

  Future<void> _removeMigrationRecord(String migrationName) async {
    final connection = _requireConnection();
    try {
      final name = _literal(toSnakeCase(migrationName));
      await connection.execute(
        'DELETE FROM $_historyTable WHERE ${_esc("migration")}=$name',
      );
    } on QueryException catch (e) {
      throw DatabaseException(
        'Failed to remove migration record $migrationName',
        e.cause,
      );
    }
  }

  Future<int> _getNextBatchNumber() async {
    if (_currentBatch != null) return _currentBatch!;
    final currentBatch = await _getCurrentBatchNumber();
    _currentBatch = currentBatch + 1;
    return _currentBatch!;
  }

  Future<int> _getCurrentBatchNumber() async {
    final connection = _requireConnection();
    try {
      final result = await connection.select(
        'SELECT COALESCE(MAX(${_esc("batch")}), 0) as max_batch '
        'FROM $_historyTable',
      );
      if (result.isEmpty) return 0;
      return int.tryParse(result.first['max_batch'].toString()) ?? 0;
    } on QueryException catch (e) {
      throw DatabaseException('Failed to get current batch number', e.cause);
    }
  }

  Future<List<String>> _getMigrationsFromBatch(int batch) async {
    final connection = _requireConnection();
    try {
      final result = await connection.select(
        'SELECT ${_esc("migration")} FROM $_historyTable '
        'WHERE ${_esc("batch")}=$batch ORDER BY ${_esc("id")} DESC',
      );
      return _migrationNames(result);
    } on QueryException catch (e) {
      throw DatabaseException('Failed to get migrations from batch', e.cause);
    }
  }

  Future<List<String>> _getAllMigrationsInReverseOrder() async {
    final connection = _requireConnection();
    try {
      final result = await connection.select(
        'SELECT ${_esc("migration")} FROM $_historyTable '
        'ORDER BY ${_esc("id")} DESC',
      );
      return _migrationNames(result);
    } on QueryException catch (e) {
      throw DatabaseException('Failed to get all migrations', e.cause);
    }
  }

  Future<List<String>> _getLastNMigrations(int n) async {
    final connection = _requireConnection();
    try {
      final result = await connection.select(
        'SELECT ${_esc("migration")} FROM $_historyTable '
        'ORDER BY ${_esc("id")} DESC LIMIT $n',
      );
      return _migrationNames(result);
    } on QueryException catch (e) {
      throw DatabaseException('Failed to get last $n migrations', e.cause);
    }
  }

  List<String> _migrationNames(List<Map<String, dynamic>> rows) =>
      rows.map((row) => row['migration'].toString()).toList();

  /// Rolling back a migration whose class is no longer registered would drop
  /// its history row while leaving the schema in place, so refuse up front
  /// rather than half-applying the rollback.
  void _assertAllRegistered(
    List<String> names,
    Map<String, Migration> migrations,
  ) {
    final missing = names.where((n) => !migrations.containsKey(n)).toList();
    if (missing.isNotEmpty) {
      throw DatabaseException(
        'Cannot roll back: no registered migration for '
        '${missing.join(', ')}. Register the missing migration class(es) or '
        'remove their rows from the ${_requireAdapter().migrationsTable} '
        'table.',
      );
    }
  }

  Future<void> _rollbackAll(
    List<String> names,
    Map<String, Migration> migrations,
  ) async {
    _assertAllRegistered(names, migrations);
    for (final migrationName in names) {
      stderr.writeln('⏪ Rolling back: $migrationName');
      await _runDown(migrationName, migrations[migrationName]!.down);
      await _removeMigrationRecord(migrationName);
    }
  }

  Future<void> _fresh(Map<String, Migration> migrations) async {
    stderr.writeln('🔄 Running fresh migration...');

    await MigrationConnection().truncateMigration();
    _currentBatch = null;

    // Reverse registration order so dependants are dropped before the tables
    // their foreign keys point at.
    for (final migration in migrations.values.toList().reversed) {
      await _runDown(migration.migrationName, migration.down);
    }

    stderr.writeln('📦 Running all migrations...');
    for (final migration in migrations.values) {
      await _runUp(migration.migrationName, migration.up);
    }
    stderr.writeln('✅ Fresh migration completed successfully!');
  }

  Future<void> _install() async {
    stderr.writeln('📋 Installing migration repository...');

    final connection = _requireConnection();
    try {
      await connection.execute(_requireAdapter().getMigrationsTableSql());
      stderr.writeln('✅ Migration repository installed successfully!');
    } on QueryException catch (e) {
      throw DatabaseException(
        'Failed to install migration repository',
        e.cause,
      );
    }
  }

  Future<void> _refresh(Map<String, Migration> migrations) async {
    stderr.writeln('🔄 Refreshing migrations...');

    await _reset(migrations);
    _currentBatch = null;
    stderr.writeln('📦 Re-running all migrations...');
    for (final migration in migrations.values) {
      await _runUp(migration.migrationName, migration.up);
    }
    stderr.writeln('✅ Migration refresh completed successfully!');
  }

  Future<void> _reset(Map<String, Migration> migrations) async {
    stderr.writeln('⏪ Resetting all migrations...');

    final allMigrations = await _getAllMigrationsInReverseOrder();
    if (allMigrations.isEmpty) {
      stderr.writeln('ℹ️ No migrations to reset.');
      return;
    }

    await _rollbackAll(allMigrations, migrations);
    stderr.writeln('✅ All migrations reset successfully!');
  }

  Future<void> _rollback(
    Map<String, Migration> migrations, {
    int? steps,
    int? batch,
  }) async {
    stderr.writeln('⏪ Rolling back migrations...');

    List<String> migrationsToRollback = [];

    if (batch != null) {
      migrationsToRollback = await _getMigrationsFromBatch(batch);
      stderr.writeln('⏪ Rolling back batch $batch...');
    } else if (steps != null) {
      migrationsToRollback = await _getLastNMigrations(steps);
      stderr.writeln('⏪ Rolling back last $steps migration(s)...');
    } else {
      final currentBatch = await _getCurrentBatchNumber();
      if (currentBatch > 0) {
        migrationsToRollback = await _getMigrationsFromBatch(currentBatch);
        stderr.writeln('⏪ Rolling back last batch ($currentBatch)...');
      }
    }

    if (migrationsToRollback.isEmpty) {
      stderr.writeln('ℹ️ No migrations to rollback.');
      return;
    }

    await _rollbackAll(migrationsToRollback, migrations);
    stderr.writeln('✅ Rollback completed successfully!');
  }
}
