import 'package:vania/vania.dart';

class CreateTaskTable extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTable('tasks', () {
      id();
      bigInt('user_id', unsigned: true);
      bigInt('task_list_id', unsigned: true);
      foreign('user_id', 'users', 'id', constrained: true);
      foreign('task_list_id', 'taskList', 'id',
          constrained: true, onDelete: 'CASCADE');
      char('title', nullable: false, length: 100);
      dateTime('created_at', nullable: false);
      dateTime('updated_at');
      dateTime('due_date');
      dateTime('remind_at');
      softDeletes('deleted_at');
      longText('note');
      text('file_address');
      enumType('status', ['todo', 'done']);
    });
  }

  @override
  Future<void> down() async {
    await super.down();
  }
}
