import 'package:vania/vania.dart';

class TaskList extends Model {
  TaskList() {
    super.table('task_lists');
  }

  static void fromJson(Map<String, dynamic> body, int userId) {}
}
