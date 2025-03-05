import 'dart:ffi';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vania/src/contract/database/_connectors/_database_connection.dart';
import '../../utils/helper.dart' show env;
import '../_database_utils/_db_config.dart';

class SQLiteConnector implements DatabaseConnection {
  final DBConfig config;
  late Database _database;

  SQLiteConnector(this.config);

  @override
  Future<void> close() async {
    _database.dispose();
  }

  @override
  Future<void> connect() async {
    try {
      open.overrideFor(OperatingSystem.linux, _openOnLinux);
      if (config.openInMemorySqlit) {
        _database = sqlite3.openInMemory();
      } else {
        _database = sqlite3
            .open(config.filePath ?? '${env<String?>('APP_NAME', 'Vania')}.db');
      }
    } catch (e) {
      throw Exception(e);
    }
  }

  DynamicLibrary _openOnLinux() {
    final scriptDir = File(Platform.script.toFilePath()).parent;
    final libraryNextToScript = File(join(scriptDir.path, 'sqlite3.so'));
    return DynamicLibrary.open(libraryNextToScript.path);
  }

  @override
  Future execute(String query) {
    try {
      final stmt = _database.prepare(query);
      stmt.execute();
      stmt.dispose();
      return Future.value(true);
    } catch (e) {
      throw Exception(e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> select(String query) async {
    try {
      final result = _database.select(query);
      return result;
    } catch (e) {
      throw Exception(e);
    }
  }

  @override
  Future insert(String query) {
    final stmt = _database.prepare(query);
    stmt.execute();
    stmt.dispose();
    return Future.value(_database.lastInsertRowId);
  }
}
