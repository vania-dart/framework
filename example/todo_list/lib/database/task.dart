import 'package:vania/vania.dart';

class Task extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTableNotExists('tasks', () {
      id();
      foreign('user_id', 'users', 'id', constrained: true);
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
}
