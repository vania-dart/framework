import 'package:vania/vania.dart';

class CreateUserTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTable('users', () {
      id();
      string('first_name', length: 20);
      string('last_name', length: 20);
      string('email', length: 50);
      string('password');
      string('avatar', nullable: true);
      timeStamp('created_at', nullable: true);
      timeStamp('updated_at', nullable: true);
      timeStamp('deleted_at', nullable: true);
      enumType('status', ['active', 'inactive', 'suspend']);
      index(ColumnIndex.unique, 'email', ['email']);
    });
  }

  @override
  Future<void> down() async {
    await super.down();
  }
}
