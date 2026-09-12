---
sidebar_position: 2
---

# Tutorial: Build a Task Manager API

This tutorial builds a task management API with projects, tasks, labels, and due date filtering. It covers many-to-many relationships, query scoping, and bulk operations.

## 1. Create the Project

```bash
vania create task_manager
cd task_manager
dart pub add vania_mysql vania_auth
dart pub get
```

Configure `.env` with your database credentials and run the initial setup as shown in the [Blog API tutorial](blog-api.md).

## 2. Create Migrations

### Projects Table

```dart
class CreateProjectsTable extends Migration {
  @override
  Future<void> up() async {
    await create('projects', (Schema schema) {
      schema.id();
      schema.integer('user_id').unsigned().foreignKey('users', 'id', onDelete: 'CASCADE');
      schema.string('name', length: 100);
      schema.text('description').nullable();
      schema.enumType('status', ['active', 'archived', 'completed']);
      schema.timeStamps();
    });
  }

  @override
  Future<void> down() async {
    await drop('projects');
  }
}
```

### Tasks Table

```dart
class CreateTasksTable extends Migration {
  @override
  Future<void> up() async {
    await create('tasks', (Schema schema) {
      schema.id();
      schema.integer('project_id').unsigned().foreignKey('projects', 'id', onDelete: 'CASCADE');
      schema.integer('assigned_to').unsigned().nullable().foreignKey('users', 'id', onDelete: 'SET NULL');
      schema.string('title', length: 255);
      schema.text('description').nullable();
      schema.enumType('priority', ['low', 'medium', 'high', 'urgent']);
      schema.enumType('status', ['todo', 'in_progress', 'review', 'done']);
      schema.dateTime('due_date').nullable();
      schema.dateTime('completed_at').nullable();
      schema.integer('sort_order').defaultTo(0);
      schema.timeStamps();
      schema.softDeletes();
    });
  }

  @override
  Future<void> down() async {
    await drop('tasks');
  }
}
```

### Labels and Pivot Table

```dart
class CreateLabelsTable extends Migration {
  @override
  Future<void> up() async {
    await create('labels', (Schema schema) {
      schema.id();
      schema.string('name', length: 50);
      schema.string('color', length: 7).defaultTo('#6366f1');
    });

    await create('label_task', (Schema schema) {
      schema.id();
      schema.integer('label_id').unsigned().foreignKey('labels', 'id', onDelete: 'CASCADE');
      schema.integer('task_id').unsigned().foreignKey('tasks', 'id', onDelete: 'CASCADE');
    });
  }

  @override
  Future<void> down() async {
    await drop('label_task');
    await drop('labels');
  }
}
```

## 3. Create Models

```dart
// lib/app/models/project.dart
import 'package:vania/database.dart';

class Project extends Model {
  @override
  List<String> get fillable => ['user_id', 'name', 'description', 'status'];

  @override
  void registerRelations() {
    belongsTo('owner', User(), foreignKey: 'user_id');
    hasMany('tasks', Task(), foreignKey: 'project_id');
  }
}
```

```dart
// lib/app/models/task.dart
import 'package:vania/database.dart';

class Task extends Model {
  @override
  List<String> get fillable => [
    'project_id', 'assigned_to', 'title', 'description',
    'priority', 'status', 'due_date', 'completed_at', 'sort_order',
  ];
  @override
  bool get softDeletes => true;

  @override
  void registerRelations() {
    belongsTo('project', Project(), foreignKey: 'project_id');
    belongsTo('assignee', User(), foreignKey: 'assigned_to');
    belongsToMany('labels', Label(), pivotTable: 'label_task',
        parentPivotKey: 'task_id', relatedPivotKey: 'label_id');
  }
}
```

```dart
// lib/app/models/label.dart
import 'package:vania/database.dart';

class Label extends Model {
  @override
  List<String> get fillable => ['name', 'color'];
  @override
  bool get timestamps => false;

  @override
  void registerRelations() {
    belongsToMany('tasks', Task(), pivotTable: 'label_task',
        parentPivotKey: 'label_id', relatedPivotKey: 'task_id');
  }
}
```

## 4. Create Controllers

### Project Controller

```dart
// lib/app/http/controllers/project_controller.dart
import 'package:vania/vania.dart';
import 'package:vania/http/controller.dart';
import 'package:vania/http/request.dart';
import 'package:vania/http/response.dart';
import 'package:task_manager/app/models/project.dart';

class ProjectController extends Controller {
  Future<Response> index(Request req) async {
    final projects = await Project().query
        .where('user_id', '=', req.user?['id'])
        .include('tasks')
        .orderByDesc('created_at')
        .get();
    return Response.json(projects);
  }

  Future<Response> store(Request req) async {
    req.validate({
      'name': 'required|string|max_length:100',
      'description': 'string',
    });

    final project = await Project().query.create({
      'user_id': req.user?['id'],
      'name': req.input('name'),
      'description': req.input('description'),
      'status': 'active',
    });

    return Response.json(project, 201);
  }

  Future<Response> show(Request req, int id) async {
    final project = await Project().query
        .where('user_id', '=', req.user?['id'])
        .include('tasks')
        .findOrFail(id);
    return Response.json(project);
  }

  Future<Response> update(Request req, int id) async {
    req.validate({
      'name': 'string|max_length:100',
      'status': 'in:active,archived,completed',
    });

    await Project().query
        .where('id', '=', id)
        .where('user_id', '=', req.user?['id'])
        .update(req.only(['name', 'description', 'status']));

    return Response.json({'message': 'Updated'});
  }

  Future<Response> destroy(Request req, int id) async {
    await Project().query
        .where('id', '=', id)
        .where('user_id', '=', req.user?['id'])
        .delete();
    return Response.json({'message': 'Deleted'});
  }
}

final ProjectController projectController = ProjectController();
```

### Task Controller

```dart
// lib/app/http/controllers/task_controller.dart
import 'package:vania/vania.dart';
import 'package:vania/http/controller.dart';
import 'package:vania/http/request.dart';
import 'package:vania/http/response.dart';
import 'package:vania/database.dart';
import 'package:task_manager/app/models/task.dart';

class TaskController extends Controller {
  Future<Response> index(Request req, int projectId) async {
    var query = Task().query
        .where('project_id', '=', projectId)
        .include('assignee:id,name')
        .include('labels');

    // Filter by status
    final status = req.query('status');
    if (status != null) {
      query = query.where('status', '=', status);
    }

    // Filter by priority
    final priority = req.query('priority');
    if (priority != null) {
      query = query.where('priority', '=', priority);
    }

    // Filter overdue tasks
    if (req.query('overdue') == 'true') {
      query = query
          .whereNotNull('due_date')
          .where('due_date', '<', DateTime.now().toIso8601String())
          .whereNotEqualTo('status', 'done');
    }

    final tasks = await query.orderBy('sort_order', 'asc').get();
    return Response.json(tasks);
  }

  Future<Response> store(Request req, int projectId) async {
    req.validate({
      'title': 'required|string|max_length:255',
      'priority': 'in:low,medium,high,urgent',
      'due_date': 'date',
      'assigned_to': 'integer',
    });

    final task = await Task().query.create({
      'project_id': projectId,
      'title': req.input('title'),
      'description': req.input('description'),
      'priority': req.input('priority', 'medium'),
      'status': 'todo',
      'due_date': req.input('due_date'),
      'assigned_to': req.input('assigned_to'),
    });

    // Attach labels if provided
    final labels = req.input('label_ids');
    if (labels is List && labels.isNotEmpty) {
      for (var labelId in labels) {
        await DB.table('label_task').insert({
          'task_id': task['id'],
          'label_id': labelId,
        });
      }
    }

    return Response.json(task, 201);
  }

  Future<Response> updateStatus(Request req, int projectId, int id) async {
    req.validate({'status': 'required|in:todo,in_progress,review,done'});

    final updates = <String, dynamic>{'status': req.input('status')};

    if (req.input('status') == 'done') {
      updates['completed_at'] = DateTime.now().toIso8601String();
    }

    await Task().query
        .where('id', '=', id)
        .where('project_id', '=', projectId)
        .update(updates);

    return Response.json({'message': 'Status updated'});
  }

  Future<Response> reorder(Request req, int projectId) async {
    req.validate({
      'tasks': 'required|array',
      'tasks.*.id': 'required|integer',
      'tasks.*.sort_order': 'required|integer',
    });

    final tasks = req.input('tasks') as List;
    for (var item in tasks) {
      await Task().query
          .where('id', '=', item['id'])
          .where('project_id', '=', projectId)
          .update({'sort_order': item['sort_order']});
    }

    return Response.json({'message': 'Reordered'});
  }

  Future<Response> destroy(int projectId, int id) async {
    await Task().query
        .where('id', '=', id)
        .where('project_id', '=', projectId)
        .delete();
    return Response.json({'message': 'Deleted'});
  }
}

final TaskController taskController = TaskController();
```

## 5. Define Routes

```dart
// lib/route/api_route.dart
class ApiRoute implements Route {
  @override
  void register() {
    Router.basePrefix('api');

    Router.post('/register', authController.register);
    Router.post('/login', authController.login);

    Router.group(() {
      // Projects
      Router.get('/projects', projectController.index);
      Router.post('/projects', projectController.store);
      Router.get('/projects/{id}', projectController.show).whereInt('id');
      Router.put('/projects/{id}', projectController.update).whereInt('id');
      Router.delete('/projects/{id}', projectController.destroy).whereInt('id');

      // Tasks (nested under projects)
      Router.get('/projects/{projectId}/tasks', taskController.index).whereInt('projectId');
      Router.post('/projects/{projectId}/tasks', taskController.store).whereInt('projectId');
      Router.patch('/projects/{projectId}/tasks/{id}/status', taskController.updateStatus);
      Router.put('/projects/{projectId}/tasks/reorder', taskController.reorder).whereInt('projectId');
      Router.delete('/projects/{projectId}/tasks/{id}', taskController.destroy);

      // Labels
      Router.get('/labels', labelController.index);
      Router.post('/labels', labelController.store);
    }, middleware: [Authenticate()]);
  }
}
```

## 6. Test It

```bash
vania serve
```

Create a project:

```bash
curl -X POST http://localhost:8000/api/projects \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"My Project","description":"A sample project"}'
```

Add a task:

```bash
curl -X POST http://localhost:8000/api/projects/1/tasks \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"Set up database","priority":"high","due_date":"2026-07-20"}'
```

Filter overdue tasks:

```bash
curl "http://localhost:8000/api/projects/1/tasks?overdue=true" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

Update task status:

```bash
curl -X PATCH http://localhost:8000/api/projects/1/tasks/1/status \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status":"done"}'
```

This gives you a fully functional task manager with nested resources, query filtering, soft deletes, many-to-many labels, and task reordering.
