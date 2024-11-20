import 'dart:io';

import 'package:eloquent/eloquent.dart';
import 'package:vaniaFramework/src/exception/http_exception.dart';

extension DatabaseOperationExtension on QueryBuilder {
  // Create and return inserted data
  /// Creates a new entry in the database and returns the inserted record.
  ///
  /// This method inserts a new record using the provided [data] and retrieves the inserted record
  /// by its ID. If no record is found after insertion, it returns an empty map.
  ///
  /// **Parameters:**
  /// - [data]: A map of key-value pairs representing the data to be inserted into the database.
  ///
  /// **Returns:**
  /// A `Map<String, dynamic>` representing the inserted record. If the insertion is successful but the
  /// record cannot be retrieved, returns an empty map.
  ///
  /// **Example Usage:**
  /// ```dart
  /// var queryBuilder = QueryBuilder();
  /// var data = {'name': 'John Doe', 'age': 30};
  /// var newRecord = await queryBuilder.create(data);
  /// print(newRecord); // Outputs: {'id': 1, 'name': 'John Doe', 'age': 30}
  /// ```
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final insertId = await insertGetId(data);
    final record = await where('id', '=', insertId).first();
    return record ?? {};
  }

  /// Inserts multiple records into the database.
  ///
  /// This method inserts each map from the [data] list into the database. If an error occurs
  /// during insertion, a [HttpResponseException] is thrown with details of the error.
  ///
  /// **Parameters:**
  /// - [data]: A list of maps, where each map contains key-value pairs representing the data for one record.
  ///
  /// **Returns:**
  /// A boolean value, `true` if all inserts are successful.
  ///
  /// **Throws:**
  /// - [HttpResponseException]: If an insertion fails, detailing the SQL error and setting an internal server error status.
  ///
  /// **Example Usage:**
  /// ```dart
  /// var queryBuilder = QueryBuilder();
  /// var dataList = [
  ///   {'name': 'John Doe', 'age': 30},
  ///   {'name': 'Jane Smith', 'age': 25}
  /// ];
  /// try {
  ///   bool success = await queryBuilder.insertMany(dataList);
  ///   print('Insertion successful: $success');
  /// } catch (e) {
  ///   print('Failed to insert: ${e.message}');
  /// }
  /// ```
  Future<bool> insertMany(List<Map<String, dynamic>> data) async {
    for (Map<String, dynamic> row in data) {
      try {
        await insert(row);
      } on QueryException catch (e) {
        throw HttpResponseException(
          message: e.sql,
          code: HttpStatus.internalServerError,
        );
      }
    }
    return true;
  }
}
