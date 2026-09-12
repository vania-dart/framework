import 'package:vania/database.dart';

class CreatePersonalAccessTokensTable extends Migration {
  @override
  Future<void> up() async {
    await create('personal_access_tokens', (Schema schema) {
      schema.id();
      schema.string('name');
      schema.bigInt('tokenable_id');
      schema.string('token').unique();
      schema.timeStamp('expires_at').nullable();
      schema.timeStamp('last_used_at').nullable();
      schema.timeStamp('revoked_at').nullable();
      schema.timeStamps();
    }, true);
  }

  @override
  Future<void> down() async {
    await drop('personal_access_tokens');
  }
}
