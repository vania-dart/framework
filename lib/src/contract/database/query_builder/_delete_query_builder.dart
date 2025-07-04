part of 'query_builder.dart';

abstract interface class DeleteQueryBuilder {
  Future<bool> delete();
  Future<bool> truncate({bool force = false});
}
