import 'package:vania/foundation.dart' show DatabaseException;

import 'mongo_connection.dart';
import 'mongo_query_builder.dart';

class MongoDB {
  static final MongoDB _singleton = MongoDB._internal();

  factory MongoDB() => _singleton;

  MongoDB._internal();

  MongoConnection? _connection;

  MongoConnection get connection {
    final current = _connection;
    if (current == null) {
      throw DatabaseException('MongoDB connection has not been configured.');
    }
    return current;
  }

  set connection(MongoConnection connection) {
    _connection = connection;
  }

  static MongoQueryBuilder collection(String name) {
    return MongoQueryBuilder(MongoDB().connection.collection(name));
  }

  Future<void> close() => connection.close();
}
