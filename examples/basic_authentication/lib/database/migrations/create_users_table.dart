import 'package:vania/database.dart';

class CreateUsersTable extends Migration {
  @override
  Future<void> up() async {
    await create('users', (Schema schema) {
      schema.id();
      schema.string('name');
      schema.string('email').unique();
      schema.string('password');
      schema.timeStamps();
    }, true);
  }

  @override
  Future<void> down() async {
    await drop('users');
  }
}
