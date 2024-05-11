import 'package:vania/vania.dart';

class TaskList extends Migration {
  @override
  Future<void> up() async {
    super.up();
    await createTableNotExists('task_lists', () {
      id();
      foreign('user_id', 'users', 'id', constrained: true);
      integer('color');
      text('background_photo');
      char('emoji');
    });
  }
}
