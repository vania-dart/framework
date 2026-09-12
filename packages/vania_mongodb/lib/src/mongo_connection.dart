import 'package:mongo_dart/mongo_dart.dart';
import 'package:vania/foundation.dart' show DatabaseException;

import 'mongo_config.dart';

class MongoConnection {
  MongoConnection(this.config);

  final MongoConfig config;
  Db? _db;

  Db get db {
    final current = _db;
    if (current == null || !current.isConnected) {
      throw DatabaseException('MongoDB connection is not open.');
    }
    return current;
  }

  Future<void> connect() async {
    final database = await Db.create(config.uri);
    await database.open();
    _db = database;
  }

  DbCollection collection(String name) => db.collection(name);

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
