import 'package:vania/vania.dart';

class CreatePersonalAccessTokensTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTable('personal_access_tokens', () {
      id();
      tinyText('name');
      bigInt('tokenable_id');
      string('token');
      timeStamp('last_used_at', nullable: true);
      timeStamp('created_at', nullable: true);
      timeStamp('deleted_at', nullable: true);

      index(ColumnIndex.unique, 'token', ['token']);
    });
  }
}
