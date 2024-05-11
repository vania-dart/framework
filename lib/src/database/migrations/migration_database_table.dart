import 'package:vania/vania.dart';

class MigrationDatabaseTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTableNotExists('migrations', () {
      id();
      string("migration");
      integer("batch", length: 11);
    });
  }

  @override
  Future<void> down() async {
    super.down();
    dropIfExists("migrations");
  }
}
