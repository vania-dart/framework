import 'dart:io';

import 'package:vania/query_builder.dart';

import '../../../utils/functions.dart';
import '../migration.dart';
import '../migration_connection.dart';

class MigrationRunner {
  int? _currentBatch;
  final Map<String, Migration> _migrations = {};

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
          ' Migration $migrationName executed ....................................\x1B[32m ${stopwatch.elapsedMilliseconds}ms DONE\x1B[0m');
    } catch (e) {
      stopwatch.stop();
      if (e is QueryException) {
        stderr.write(e.cause);
      }
      stderr.writeln(
          '❌ Migration $migrationName failed ......................................\x1B[31m ${stopwatch.elapsedMilliseconds}ms FAILED\x1B[0m');
      exit(1);
    }
  }

  MigrationRunner migrationRegister(List<Migration> migrations) {
    _migrations.clear();
    for (var migration in migrations) {
      String name = migration.migrationName;
      if (!_migrations.containsKey(name)) {
        _migrations[name] = migration;
      }
    }
    return this;
  }

  Future<void> run(List<String> args) async {
    if (MigrationConnection().connection == null) {
      stderr.writeln(
        'Database connection not established',
      );
      exit(1);
    }
    if (args.contains('--fresh')) {
      await _fresh(_migrations.values.toList());
    } else if (args.contains('--install')) {
      await _install();
    } else if (args.contains('--refresh')) {
      await _refresh(_migrations);
    } else if (args.contains('--reset')) {
      await _reset(_migrations);
    } else if (args.contains('--rollback')) {
      int? steps = args.contains('--steps')
          ? int.tryParse(args[args.indexOf('--steps') + 1])
          : null;
      int? batch = args.contains('--batch')
          ? int.tryParse(args[args.indexOf('--batch') + 1])
          : null;
      await _rollback(_migrations, steps: steps, batch: batch);
    } else {
      for (final migration in _migrations.values) {
        await _runUp(migration.migrationName, migration.up);
      }
      stderr.writeln('✅ All migrations executed successfully!');
    }
  }

  Future<void> _runDown(
      String migrationName, Function migrationCallback) async {
    final stopwatch = Stopwatch()..start();

    try {
      await Future.delayed(Duration(milliseconds: 30));
      await migrationCallback();

      stopwatch.stop();
      stderr.writeln(
          ' Migration $migrationName rolled back....................................\x1B[32m ${stopwatch.elapsedMilliseconds}ms DONE\x1B[0m');
    } catch (e) {
      stopwatch.stop();
      stderr.writeln(
          ' Migration $migrationName failed ......................................\x1B[31m ${stopwatch.elapsedMilliseconds}ms FAILED\x1B[0m');
      exit(1);
    }
  }

  Future<bool> _isMigrationExecuted(String migrationName) async {
    if (MigrationConnection().connection == null) {
      stderr.writeln(
        'Database connection not established',
      );
      exit(1);
    }

    try {
      final snakeCaseName = toSnakeCase(migrationName);
      final result = await MigrationConnection()
          .connection!
          .select("SELECT id FROM migrations WHERE migration='$snakeCaseName'");

      return result.isNotEmpty;
    } catch (e) {
      if (e is QueryException) {
        stderr
            .writeln('❌ Failed to check if migration is executed: ${e.cause}');
      } else {
        stderr.writeln('❌ Failed to check if migration is executed: $e');
      }
      exit(1);
    }
  }

  Future<void> _recordMigrationWithBatch(
      String migrationName, int batch) async {
    if (MigrationConnection().connection == null) {
      stderr.writeln(
        'Database connection not established',
      );
      exit(1);
    }

    try {
      final snakeCaseName = toSnakeCase(migrationName);

      String sql;
      if (MigrationConnection().adapter?.driverName == 'mysql') {
        sql =
            'INSERT INTO `migrations` (`migration`, `batch`) VALUES (\'$snakeCaseName\', $batch)';
      } else {
        sql =
            'INSERT INTO "migrations" ("migration", "batch") VALUES (\'$snakeCaseName\', $batch)';
      }

      await Future.delayed(Duration(milliseconds: 100));
      await MigrationConnection().connection!.execute(sql);
    } catch (e) {
      if (e is QueryException) {
        stderr.writeln('❌ Failed to record migration with batch: ${e.cause}');
      } else {
        stderr.writeln('❌ Failed to record migration with batch: $e');
      }
      exit(1);
    }
  }

  Future<void> _removeMigrationRecord(String migrationName) async {
    if (MigrationConnection().connection == null) {
      stderr.writeln(
        'Database connection not established',
      );
      exit(1);
    }

    try {
      final snakeCaseName = toSnakeCase(migrationName);
      String sql;
      if (MigrationConnection().adapter?.driverName == 'mysql') {
        sql = 'DELETE FROM `migrations` WHERE `migration`=\'$snakeCaseName\'';
      } else {
        sql = 'DELETE FROM "migrations" WHERE "migration"=\'$snakeCaseName\'';
      }

      await MigrationConnection().connection!.execute(sql);
    } catch (e) {
      if (e is QueryException) {
        stderr.writeln('❌ Failed to remove migration record: ${e.cause}');
      } else {
        stderr.writeln('❌ Failed to remove migration record: $e');
      }
      exit(1);
    }
  }

  Future<int> _getNextBatchNumber() async {
    if (_currentBatch != null) {
      return _currentBatch!;
    }

    final currentBatch = await _getCurrentBatchNumber();
    _currentBatch = currentBatch + 1;
    return _currentBatch!;
  }

  Future<int> _getCurrentBatchNumber() async {
    if (MigrationConnection().connection == null) {
      stderr.writeln(
        'Database connection not established',
      );
      exit(1);
    }

    try {
      String sql;
      if (MigrationConnection().adapter?.driverName == 'mysql') {
        sql = 'SELECT COALESCE(MAX(`batch`), 0) as max_batch FROM `migrations`';
      } else {
        sql = 'SELECT COALESCE(MAX("batch"), 0) as max_batch FROM "migrations"';
      }

      final result = await MigrationConnection().connection!.select(sql);
      if (result.isNotEmpty) {
        return int.parse(result.first['max_batch'].toString());
      }
      return 0;
    } catch (e) {
      if (e is QueryException) {
        stderr.writeln('❌ Failed to get current batch number: ${e.cause}');
      } else {
        stderr.writeln('❌ Failed to get current batch number: $e');
      }
      exit(1);
    }
  }

  Future<List<String>> _getMigrationsFromBatch(int batch) async {
    if (MigrationConnection().connection == null) {
      stderr.writeln('Database connection not established');
      exit(1);
    }

    try {
      String sql;
      if (MigrationConnection().adapter?.driverName == 'mysql') {
        sql =
            'SELECT `migration` FROM `migrations` WHERE `batch`=$batch  ORDER BY "id" DESC';
      } else {
        sql =
            'SELECT "migration" FROM "migrations" WHERE "batch"=$batch  ORDER BY "id" DESC';
      }

      final result = await MigrationConnection().connection!.select(sql);

      return result.map((row) => row['migration'] as String).toList();
    } catch (e) {
      if (e is QueryException) {
        stderr.writeln('❌ Failed to get migrations from batch: ${e.cause}');
      } else {
        stderr.writeln('❌ Failed to get migrations from batch: $e');
      }
      exit(1);
    }
  }

  Future<void> _fresh(List<Migration> migrations) async {
    stderr.writeln('🔄 Running fresh migration...');

    try {
      await MigrationConnection().truncateMigration();
      _currentBatch = null;

      for (final migration in _migrations.values) {
        await _runDown(migration.migrationName, migration.down);
      }

      stderr.writeln('📦 Running all migrations...');
      for (final migration in migrations) {
        await _runUp(migration.migrationName, migration.up);
      }
      stderr.writeln('✅ Fresh migration completed successfully!');
    } catch (e) {
      if (e is QueryException) {
        stderr.writeln('❌ Failed to run fresh migration: ${e.cause}');
      } else {
        stderr.writeln('❌ Failed to run fresh migration: $e');
      }
      exit(1);
    }
  }

  Future<void> _install() async {
    stderr.writeln('📋 Installing migration repository...');

    try {
      if (MigrationConnection().adapter != null) {
        String migrationSql =
            MigrationConnection().adapter!.getMigrationsTableSql();
        await MigrationConnection().connection!.execute(migrationSql);
        stderr.writeln('✅ Migration repository installed successfully!');
      } else {
        stderr.writeln('❌ Migration repository installation failed!');
        exit(1);
      }
    } catch (e) {
      if (e is QueryException) {
        stderr.writeln('❌ Failed to install migration repository: ${e.cause}');
      } else {
        stderr.writeln('❌ Failed to install migration repository: $e');
      }
      exit(1);
    }
  }

  Future<void> _refresh(Map<String, Migration> migrations) async {
    stderr.writeln('🔄 Refreshing migrations...');

    try {
      await _reset(migrations);
      _currentBatch = null;
      stderr.writeln('📦 Re-running all migrations...');
      for (final migration in migrations.values) {
        await _runUp(migration.migrationName, migration.up);
      }

      stderr.writeln('✅ Migration refresh completed successfully!');
    } catch (e) {
      if (e is QueryException) {
        stderr.writeln('❌ Failed to refresh migrations: ${e.cause}');
      } else {
        stderr.writeln('❌ Failed to refresh migrations: $e');
      }
      exit(1);
    }
  }

  Future<void> _reset(Map<String, Migration> migrations) async {
    stderr.writeln('⏪ Resetting all migrations...');

    try {
      final allMigrations = await _getAllMigrationsInReverseOrder();

      if (allMigrations.isEmpty) {
        stderr.writeln('ℹ️ No migrations to reset.');
        return;
      }
      for (final migrationName in allMigrations) {
        stderr.writeln('⏪ Rolling back: $migrationName');
        final migration = migrations[migrationName];
        if (migration != null) {
          await _runDown(migrationName, migration.down);
        }

        await _removeMigrationRecord(migrationName);
      }

      stderr.writeln('✅ All migrations reset successfully!');
    } catch (e) {
      if (e is QueryException) {
        stderr.writeln('❌ Failed to reset migrations: ${e.cause}');
      } else {
        stderr.writeln('❌ Failed to reset migrations: $e');
      }
      exit(1);
    }
  }

  Future<void> _rollback(
    Map<String, Migration> migrations, {
    int? steps,
    int? batch,
  }) async {
    stderr.writeln('⏪ Rolling back migrations...');

    try {
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

      for (final migrationName in migrationsToRollback) {
        stderr.writeln('⏪ Rolling back: $migrationName');

        final migration = migrations[migrationName];
        if (migration != null) {
          await _runDown(migrationName, migration.down);
        }
        await _removeMigrationRecord(migrationName);
      }

      stderr.writeln('✅ Rollback completed successfully!');
    } catch (e) {
      if (e is QueryException) {
        stderr.writeln('❌ Failed to rollback migrations: ${e.cause}');
      } else {
        stderr.writeln('❌ Failed to rollback migrations: $e');
      }
      exit(1);
    }
  }

  Future<List<String>> _getAllMigrationsInReverseOrder() async {
    if (MigrationConnection().connection == null) {
      stderr.writeln(
        'Database connection not established',
      );
      exit(1);
    }

    try {
      String sql;
      if (MigrationConnection().adapter?.driverName == 'mysql') {
        sql = 'SELECT `migration` FROM `migrations` ORDER BY `id` DESC';
      } else {
        sql = 'SELECT "migration" FROM "migrations" ORDER BY "id" DESC';
      }

      final result = await MigrationConnection().connection!.select(sql);
      return result.map((row) => row['migration'] as String).toList();
    } catch (e) {
      if (e is QueryException) {
        stderr.writeln('❌ Failed to get all migrations: ${e.cause}');
      } else {
        stderr.writeln('❌ Failed to get all migrations: $e');
      }
      exit(1);
    }
  }

  Future<List<String>> _getLastNMigrations(int n) async {
    if (MigrationConnection().connection == null) {
      stderr.writeln(
        'Database connection not established',
      );
      exit(1);
    }

    try {
      String sql;
      if (MigrationConnection().adapter?.driverName == 'mysql') {
        sql =
            'SELECT `migration` FROM `migrations` ORDER BY `id` DESC LIMIT $n';
      } else {
        sql =
            'SELECT "migration" FROM "migrations" ORDER BY "id" DESC LIMIT $n';
      }

      final result = await MigrationConnection().connection!.select(sql);
      return result.map((row) => row['migration'] as String).toList();
    } catch (e) {
      if (e is QueryException) {
        stderr.writeln('❌ Failed to get last $n migrations: ${e.cause}');
      } else {
        stderr.writeln('❌ Failed to get last $n migrations: $e');
      }
      exit(1);
    }
  }
}
