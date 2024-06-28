import 'dart:io';

import 'package:eloquent/eloquent.dart';
import 'package:vania/src/exception/http_exception.dart';

extension DatabaseHelper on QueryBuilder {
  // Create and return inserted data
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final insertId = await insertGetId(data);
    final record = await where('id', '=', insertId).first();
    return record ?? {};
  }

  // Insert many data in the table
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
