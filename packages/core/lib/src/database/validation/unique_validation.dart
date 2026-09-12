import 'package:vania/http/request.dart' show Rules;
import 'package:vania/database.dart';

Future<bool> ormUniqueValidationResolver(
  Map<String, dynamic> data,
  dynamic value,
  String values,
) async {
  final parts = values.toString().split(',');
  final table = parts[0];
  final column = parts[1];

  return DB.table(table).whereEqualTo(column, value).doesntExist();
}

void registerOrmValidationRules() {
  Rules.setUniqueValidationResolver(ormUniqueValidationResolver);
}
