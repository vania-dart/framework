import 'package:vania/route.dart';
import 'package:todos/features/todos/todo_controller.dart';

/// Routes owned by the todos feature. Each feature registers its own
/// `Route`, so adding a feature never means editing another feature's file.
class TodosRoute extends Route {
  @override
  String? get prefix => 'api';

  @override
  void register() {
    super.register();

    Router.get('/todos', todoController.index);
    Router.post('/todos', todoController.store);
    Router.get('/todos/{id}', todoController.show).whereInt('id');
    Router.put('/todos/{id}', todoController.update).whereInt('id');
    Router.delete('/todos/{id}', todoController.destroy).whereInt('id');
  }
}
