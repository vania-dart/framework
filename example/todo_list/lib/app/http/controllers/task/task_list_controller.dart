import 'package:todo_list/app/models/task_list.dart';
import 'package:vania/vania.dart';

class TaskListController extends Controller {
  Future<Response> getAll() async {
    var list =
        await TaskList().query().where('user_id', '=', Auth().id()).get();
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

  Future<Response> index() async {
    List<Map<String, dynamic>> taskLists = await TaskList()
        .query()
        .select([
          'users.first_name',
          'users.last_name',
          'taskList.title',
          'taskList.id',
          'taskList.background_color',
        ])
        .join('users', 'users.id', '=', 'taskList.user_id')
        .get();

    return Response.json({'data': taskLists});
  }

  Future<Response> create(Request request) async {
    request.validate({
      'title': 'required',
    }, {
      'title.required': "Title is required"
    });
    final result = await TaskList().query().insert({
      'title': request.input('title'),
      'user_id': Auth().id(),
      'created_at': DateTime.now(),
      'updated_at': DateTime.now(),
      'background_color': request.input('background_color', null),
    });

    return Response.json(
        {"message": "Task list created successfully", "data": result});
  }
}

final TaskListController taskListController = TaskListController();
