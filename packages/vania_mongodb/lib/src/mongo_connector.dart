import 'dart:convert';

import 'package:mongo_dart/mongo_dart.dart';
// mongo_dart exposes no public API for admin-database commands, and
// `Db.runCommand` targets the current database rather than `admin`.
// ignore: implementation_imports
import 'package:mongo_dart/src/database/commands/base/db_admin_command_operation.dart';
import 'package:vania/database.dart' show DatabaseConnection, DBConfig;
import 'package:vania/foundation.dart' show DatabaseException;

import 'mongo_config.dart';
import 'mongo_connection.dart';
import 'mongo_db.dart';

class MongoConnector implements DatabaseConnection {
  MongoConnector(this.config)
    : _mongoConfig = MongoConfig(uri: _buildUri(config)),
      _mongoConnection = MongoConnection(MongoConfig(uri: _buildUri(config)));

  final DBConfig config;
  final MongoConfig _mongoConfig;
  final MongoConnection _mongoConnection;

  MongoConfig get mongoConfig => _mongoConfig;
  MongoConnection get mongoConnection => _mongoConnection;

  static String _buildUri(DBConfig config) {
    if (config.host.startsWith('mongodb://') ||
        config.host.startsWith('mongodb+srv://')) {
      return config.host;
    }
    final userInfo = config.username.isNotEmpty
        ? '${config.username}:${config.password}@'
        : '';
    final port = config.port > 0 ? ':${config.port}' : '';
    final host = config.host.isNotEmpty ? config.host : 'localhost';
    return 'mongodb://$userInfo$host$port/${config.database}';
  }

  @override
  Future<void> connect() async {
    await _mongoConnection.connect();
    MongoDB().connection = _mongoConnection;
  }

  @override
  Future<void> close() async {
    await _mongoConnection.close();
  }

  @override
  Future<List<Map<String, dynamic>>> select(
    String query, [
    Map<String, dynamic> bindings = const {},
  ]) async {
    if (_isMigrationCommand(query)) {
      return _handleMigrationSelect(query);
    }

    if (_isMigrationSQL(query)) {
      return _handleSqlSelect(query);
    }

    throw DatabaseException(
      'MongoDB does not accept raw SQL. Use `DB.table(name)` / the '
      'query builder, or reach `MongoDB().connection` for driver-'
      'specific access.',
    );
  }

  @override
  Future<dynamic> insert(
    String query, [
    Map<String, dynamic> bindings = const {},
  ]) {
    throw DatabaseException(
      'MongoDB does not accept raw SQL. Use `DB.table(name).insert(...)`.',
    );
  }

  @override
  Future<bool> execute(
    String query, [
    Map<String, dynamic> bindings = const {},
  ]) async {
    if (_isMigrationCommand(query)) {
      await _handleMigrationCommand(query);
      return true;
    }

    if (_isMigrationSQL(query)) {
      await _handleMigrationSQL(query);
      return true;
    }

    throw DatabaseException(
      'MongoDB does not accept raw SQL. Use the document query builder.',
    );
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    return action();
  }

  bool _isMigrationCommand(String query) {
    return query.trimLeft().startsWith('{"_vania_migration"');
  }

  bool _isMigrationSQL(String query) {
    final upper = query.trim().toUpperCase();
    return upper.startsWith('INSERT INTO') ||
        upper.startsWith('DELETE FROM') ||
        upper.startsWith('SELECT ') ||
        upper.startsWith('TRUNCATE ') ||
        upper.startsWith('CREATE TABLE');
  }

  Future<void> _handleMigrationCommand(String query) async {
    final cmd = jsonDecode(query) as Map<String, dynamic>;
    final action = cmd['_vania_migration'] as String;

    switch (action) {
      case 'createCollection':
        await _createCollection(cmd);
      case 'dropCollection':
        await _dropCollection(cmd);
      case 'truncateCollection':
        await _truncateCollection(cmd);
      case 'createIndex':
        await _createIndex(cmd);
      case 'dropIndex':
        await _dropIndex(cmd);
      case 'removeField':
        await _removeField(cmd);
      case 'renameField':
        await _renameField(cmd);
      case 'renameCollection':
        await _renameCollection(cmd);
      case 'addValidatorFields':
        await _addValidatorFields(cmd);
      default:
        throw DatabaseException('Unknown migration command: $action');
    }
  }

  Future<void> _createCollection(Map<String, dynamic> cmd) async {
    final name = cmd['name'] as String;
    final db = _mongoConnection.db;

    final collections = await db.getCollectionNames();
    if (collections.contains(name)) return;

    final options = cmd['options'] as Map<String, dynamic>?;
    if (options != null && options.containsKey('validator')) {
      await db.createCollection(
        name,
        createCollectionOptions: CreateCollectionOptions(
          validator: options['validator'] as Map<String, dynamic>,
        ),
      );
    } else {
      await db.createCollection(name);
    }
  }

  Future<void> _dropCollection(Map<String, dynamic> cmd) async {
    final name = cmd['name'] as String;
    final db = _mongoConnection.db;
    try {
      await db.dropCollection(name);
    } catch (_) {}
  }

  Future<void> _truncateCollection(Map<String, dynamic> cmd) async {
    final name = cmd['name'] as String;
    final db = _mongoConnection.db;
    await db.collection(name).deleteMany(<String, dynamic>{});
  }

  Future<void> _createIndex(Map<String, dynamic> cmd) async {
    final collection = cmd['collection'] as String;
    final keys = (cmd['keys'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, v as Object),
    );
    final options = cmd['options'] as Map<String, dynamic>? ?? {};
    final unique = options['unique'] == true;
    final indexName = options['name'] as String?;

    final db = _mongoConnection.db;
    await db.createIndex(
      collection,
      keys: keys,
      unique: unique,
      name: indexName,
    );
  }

  Future<void> _dropIndex(Map<String, dynamic> cmd) async {
    final collectionName = cmd['collection'] as String;
    final indexName = cmd['indexName'] as String;
    final db = _mongoConnection.db;

    await db.runCommand({'dropIndexes': collectionName, 'index': indexName});
  }

  Future<void> _removeField(Map<String, dynamic> cmd) async {
    final collection = cmd['collection'] as String;
    final field = cmd['field'] as String;
    final db = _mongoConnection.db;

    await db
        .collection(collection)
        .updateMany(where, ModifierBuilder().unset(field));
  }

  Future<void> _renameField(Map<String, dynamic> cmd) async {
    final collection = cmd['collection'] as String;
    final oldName = cmd['oldName'] as String;
    final newName = cmd['newName'] as String;
    final db = _mongoConnection.db;

    await db
        .collection(collection)
        .updateMany(where, ModifierBuilder().rename(oldName, newName));
  }

  Future<void> _renameCollection(Map<String, dynamic> cmd) async {
    final oldName = cmd['oldName'] as String;
    final newName = cmd['newName'] as String;
    final db = _mongoConnection.db;

    await DbAdminCommandOperation(db, {
      'renameCollection': '${db.databaseName}.$oldName',
      'to': '${db.databaseName}.$newName',
    }).execute();
  }

  Future<void> _addValidatorFields(Map<String, dynamic> cmd) async {
    final collection = cmd['collection'] as String;
    final db = _mongoConnection.db;

    final collections = await db.getCollectionNames();
    if (!collections.contains(collection)) {
      await db.createCollection(collection);
    }
  }

  Future<List<Map<String, dynamic>>> _handleMigrationSelect(
    String query,
  ) async {
    final cmd = jsonDecode(query) as Map<String, dynamic>;
    final action = cmd['_vania_migration'] as String;

    if (action == 'find') {
      final collection = cmd['collection'] as String;
      final filter = cmd['filter'] as Map<String, dynamic>? ?? {};
      final limit = cmd['limit'] as int?;

      final db = _mongoConnection.db;
      final results = await db.collection(collection).find(filter).toList();

      if (limit != null) {
        return results.take(limit).toList();
      }
      return results;
    }

    throw DatabaseException('Unknown migration select command: $query');
  }

  Future<List<Map<String, dynamic>>> _handleSqlSelect(String query) async {
    final upper = query.trim().toUpperCase();
    final db = _mongoConnection.db;

    if (upper.startsWith('SELECT')) {
      final tableMatch = RegExp(
        r'FROM\s+[`"]*(\w+)[`"]*',
        caseSensitive: false,
      ).firstMatch(query);
      if (tableMatch == null) return [];

      final table = tableMatch.group(1)!;

      final whereMatch = RegExp(
        r"""WHERE\s+[`"]*(\w+)[`"]*\s*=\s*'?([^']+)'?""",
        caseSensitive: false,
      ).firstMatch(query);

      Map<String, dynamic> filter = {};
      if (whereMatch != null) {
        final col = whereMatch.group(1)!;
        final val = whereMatch.group(2)!;
        filter[col] = int.tryParse(val) ?? val;
      }

      final results = await db.collection(table).find(filter).toList();

      if (upper.contains('ORDER BY') && upper.contains('DESC')) {
        results.sort((a, b) {
          final aId = a['_id'];
          final bId = b['_id'];
          if (aId is ObjectId && bId is ObjectId) {
            return bId.oid.compareTo(aId.oid);
          }
          return 0;
        });
      }

      final limitMatch = RegExp(
        r'LIMIT\s+(\d+)',
        caseSensitive: false,
      ).firstMatch(query);
      if (limitMatch != null) {
        final limit = int.parse(limitMatch.group(1)!);
        return results.take(limit).toList();
      }

      if (upper.contains('COALESCE') || upper.contains('MAX(')) {
        if (results.isEmpty) {
          return [
            {'max_batch': 0},
          ];
        }
        int maxBatch = 0;
        for (final row in results) {
          final batch = row['batch'];
          if (batch is int && batch > maxBatch) maxBatch = batch;
        }
        return [
          {'max_batch': maxBatch},
        ];
      }

      return results;
    }

    return [];
  }

  Future<void> _handleMigrationSQL(String query) async {
    final upper = query.trim().toUpperCase();
    final db = _mongoConnection.db;

    if (upper.startsWith('INSERT INTO')) {
      final match = RegExp(
        r'INSERT\s+INTO\s+[`"]*(\w+)[`"]*\s*\((.+?)\)\s*VALUES\s*\((.+?)\)',
        caseSensitive: false,
      ).firstMatch(query);
      if (match != null) {
        final table = match.group(1)!;
        final cols = match
            .group(2)!
            .split(',')
            .map((c) => c.trim().replaceAll(RegExp(r'[`"\[\]]'), ''))
            .toList();
        final vals = match
            .group(3)!
            .split(',')
            .map((v) => v.trim().replaceAll("'", ''))
            .toList();

        final doc = <String, dynamic>{};
        for (var i = 0; i < cols.length && i < vals.length; i++) {
          doc[cols[i]] = int.tryParse(vals[i]) ?? vals[i];
        }
        await db.collection(table).insertOne(doc);
        return;
      }
    }

    if (upper.startsWith('DELETE FROM')) {
      final match = RegExp(
        r"""DELETE\s+FROM\s+[`"]*(\w+)[`"]*\s+WHERE\s+[`"]*(\w+)[`"]*\s*=\s*'?([^']+)'?""",
        caseSensitive: false,
      ).firstMatch(query);
      if (match != null) {
        final table = match.group(1)!;
        final col = match.group(2)!;
        final val = match.group(3)!;
        await db.collection(table).deleteMany({col: int.tryParse(val) ?? val});
        return;
      }
    }

    if (upper.startsWith('TRUNCATE')) {
      final match = RegExp(
        r'TRUNCATE\s+[`"]*(\w+)[`"]*',
        caseSensitive: false,
      ).firstMatch(query);
      if (match != null) {
        final table = match.group(1)!;
        await db.collection(table).deleteMany(<String, dynamic>{});
        return;
      }
    }

    if (upper.startsWith('CREATE TABLE')) {
      return;
    }
  }
}

DbCollection resolveCollection(String name) =>
    MongoDB().connection.collection(name);
