import 'package:vania/http/controller.dart';
import 'package:vania/http/request.dart';
import 'package:vania/http/response.dart';
import 'package:todos/features/todos/todo_repository.dart';

class TodoController extends Controller {
  Future<Response> index(Request req) async {
    return Response.json({
      'data': todoRepository.all().map((t) => t.toJson()).toList(),
    });
  }

  Future<Response> show(Request req, int id) async {
    final todo = todoRepository.find(id);
    if (todo == null) {
      return Response.json({'message': 'Not found'}, 404);
    }
    return Response.json(todo.toJson());
  }

  Future<Response> store(Request req) async {
    await req.validate({'title': 'required|string|max_length:255'});
    final todo = todoRepository.create(req.input('title') as String);
    return Response.json(todo.toJson(), 201);
  }

  Future<Response> update(Request req, int id) async {
    final todo = todoRepository.update(
      id,
      title: req.input('title') as String?,
      completed: req.input('completed') as bool?,
    );
    if (todo == null) {
      return Response.json({'message': 'Not found'}, 404);
    }
    return Response.json(todo.toJson());
  }

  Future<Response> destroy(Request req, int id) async {
    if (!todoRepository.delete(id)) {
      return Response.json({'message': 'Not found'}, 404);
    }
    return Response.json({'message': 'Deleted'});
  }
}

final TodoController todoController = TodoController();
