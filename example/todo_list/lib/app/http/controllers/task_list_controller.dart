import 'package:todo_list/app/models/task_list.dart';
import 'package:vania/vania.dart';

class TaskListController extends Controller {
  Future<Response> getAll(int userId) async {
    var list = await TaskList().query().where('user_id', '=', userId).get();
    return Response.json(list);
  }

  Future<Response> getInfo(
    int userId,
    int listId,
  ) async {
    var list = await TaskList()
        .query()
        .where('id', '=', listId)
        .where('user_id', '=', userId)
        .get();
    return Response.json(list);
  }

  Future<Response> create(int userId, Request request) async {
    // todo check request body using middleware
    final result = await TaskList().query().insert(request.body);
    return Response.json(result);
  }

  Future<Response> update(int userId, int listId, Request request) async {
    // todo check request body using middleware
    final result = await TaskList().query().update(request.body);
    return Response.json(result);
  }
}
final TaskListController taskListController = TaskListController();

