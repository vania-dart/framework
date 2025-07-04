import 'dart:ffi';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vania/src/contract/database/_connectors/_database_connection.dart';
import 'package:vania/src/exception/database_exception.dart';
import 'package:vania/src/exception/query_exception.dart';
import '../../utils/helper.dart' show env;
import '../_database_utils/_db_config.dart';

class SQLiteConnector implements DatabaseConnection {
  final DBConfig config;
  late Database _connection;

  SQLiteConnector(this.config);

  @override
  Future<void> close() async {
    _connection.dispose();
  }

  @override
  Future<void> connect() async {
    try {
      open.overrideFor(OperatingSystem.linux, _openOnLinux);

      if (config.openInMemorySQLite) {
        _connection = sqlite3.openInMemory();
      } else {
        _connection = sqlite3
            .open(config.filePath ?? '${env<String?>('APP_NAME', 'Vania')}.db');
      }
    } catch (e) {
      throw DatabaseException('Database connection failed', e);
    }
  }

  DynamicLibrary _openOnLinux() {
    final scriptDir = File(Platform.script.toFilePath()).parent;

    final libraryNextToScript = File(join(scriptDir.path, 'sqlite3.so'));

    return DynamicLibrary.open(libraryNextToScript.path);
  }

  List<dynamic> _convertBindingsToList(
      Map<String, dynamic> bindings, String query) {
    if (bindings.isEmpty) return [];

    final List<dynamic> result = [];
    final parameterRegex = RegExp(r':(\w+)');

    final matches = parameterRegex.allMatches(query);
    for (final match in matches) {
      final paramName = match.group(1)!;
      if (bindings.containsKey(paramName)) {
        result.add(bindings[paramName]);
      }
    }

    return result;
  }

  String _convertNamedParamsToPositional(String query) {
    return query.replaceAllMapped(
      RegExp(r':(\w+)'),
      (match) => '?',
    );
  }

  @override
  Future<bool> execute(String query,
      [Map<String, dynamic> bindings = const {}]) async {
    try {
      final positionalQuery = _convertNamedParamsToPositional(query);
      final params = _convertBindingsToList(bindings, query);

      final stmt = _connection.prepare(positionalQuery);
      stmt.execute(params);
      stmt.dispose();

      return true;
    } catch (e) {
      throw QueryException(
        e.toString(),
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> select(String query,
      [Map<String, dynamic> bindings = const {}]) async {
    try {
      final positionalQuery = _convertNamedParamsToPositional(query);
      final params = _convertBindingsToList(bindings, query);

      final stmt = _connection.prepare(positionalQuery);
      final results = stmt.select(params);

      final List<Map<String, dynamic>> rows = [];
      final columns = results.isEmpty ? [] : results.first.keys.toList();

      for (final row in results) {
        final map = <String, dynamic>{};
        for (var i = 0; i < columns.length; i++) {
          map[columns[i]] = row[i.toString()];
        }
        rows.add(map);
      }

      stmt.dispose();
      return rows;
    } catch (e) {
      throw QueryException(
        e.toString(),
      );
    }
  }

  @override
  Future insert(String query,
      [Map<String, dynamic> bindings = const {}]) async {
    try {
      final positionalQuery = _convertNamedParamsToPositional(query);
      final params = _convertBindingsToList(bindings, query);

      final stmt = _connection.prepare(positionalQuery);
      stmt.execute(params);
      final id = _connection.lastInsertRowId;
      stmt.dispose();

      return id;
    } catch (e) {
      throw QueryException(
        e.toString(),
      );
    }
  }
}
