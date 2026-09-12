import '../mongo_db.dart';
import '../contract/database/query_builder/query_builder.dart';
import 'query_builder/mongo_query_builder_impl.dart';

class DB {
  const DB._();

  static QueryBuilder collection(String name) {
    return MongoQueryBuilderImpl(MongoDB().connection.collection(name));
  }

  static QueryBuilder table(String name) => collection(name);
}
