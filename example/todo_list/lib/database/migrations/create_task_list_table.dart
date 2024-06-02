import 'package:vania/vania.dart';

class CreateTaskListTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTable('taskList', () {
      id();
      foreign('user_id', 'users', 'id', constrained: true);
      char('title', nullable: false, length: 100);
      dateTime('created_at', nullable: false);
      dateTime('updated_at');
      softDeletes('deleted_at');
      string('background_image', nullable: true);
      string('background_color', nullable: true);
    });
  }

  @override
  Future<void> down() async {
    await super.down();
  }
}
