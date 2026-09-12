import 'package:vania/database.dart';

class User extends Model {
  @override
  List<String> get fillable => ['name', 'email', 'password'];

  @override
  List<String> get hidden => ['password'];
}
