---
sidebar_position: 2
---

# Controllers

Controllers organize your request handling logic into classes. Each public method handles a specific route and returns a `Response`.

## Defining a Controller

```dart
import 'package:vania/vania.dart';
import 'package:vania/http/controller.dart';
import 'package:vania/http/request.dart';
import 'package:vania/http/response.dart';

class PostController extends Controller {
  Future<Response> index() async {
    final posts = await Post().query.get();
    return Response.json(posts);
  }

  Future<Response> show(int id) async {
    final post = await Post().query.findOrFail(id);
    return Response.json(post);
  }

  Future<Response> store(Request req) async {
    req.validate({
      'title': 'required|string|max_length:255',
      'body': 'required|string',
    });

    final post = await Post().query.create({
      'title': req.input('title'),
      'body': req.input('body'),
    });

    return Response.json(post, 201);
  }

  Future<Response> update(Request req, int id) async {
    req.validate({
      'title': 'required|string|max_length:255',
      'body': 'required|string',
    });

    await Post().query.where('id', '=', id).update({
      'title': req.input('title'),
      'body': req.input('body'),
    });

    return Response.json({'message': 'Updated'});
  }

  Future<Response> destroy(int id) async {
    await Post().query.where('id', '=', id).delete();
    return Response.json({'message': 'Deleted'});
  }
}

final PostController postController = PostController();
```

## Controller Instantiation

Controllers are instantiated as top-level singletons. Define a final instance at the bottom of the controller file and reference it in your route definitions:

```dart
final PostController postController = PostController();
```

In your route file:

```dart
Router.get('/posts', postController.index);
Router.post('/posts', postController.store);
Router.get('/posts/{id}', postController.show);
```

## Method Signatures

Controller methods can accept any combination of:

- **`Request req`** — the current HTTP request. Must be the first parameter if present.
- **Route parameters** — positional arguments matching `{param}` segments in the route path. The framework parses `int`, `double`, and `bool` types automatically based on your method signature.

```dart
// No parameters
Future<Response> index() async { ... }

// Request only
Future<Response> store(Request req) async { ... }

// Route parameter only
Future<Response> show(int id) async { ... }

// Both
Future<Response> update(Request req, int id) async { ... }
```

## Resource Controllers

When using `Router.resource()`, your controller should implement the seven standard methods:

```dart
class ArticleController extends Controller {
  Future<Response> index() async { ... }
  Future<Response> create() async { ... }
  Future<Response> store(Request req) async { ... }
  Future<Response> show(int id) async { ... }
  Future<Response> edit(int id) async { ... }
  Future<Response> update(Request req, int id) async { ... }
  Future<Response> destroy(int id) async { ... }
}
```

Register with:

```dart
Router.resource('/articles', articleController);
```

## WebSocket Controllers

For WebSocket event handlers, the method signature receives a `WebSocketClient` and the message payload:

```dart
class ChatController extends Controller {
  void newMessage(WebSocketClient client, dynamic message) {
    client.toRoom('message', 'general', message);
  }

  void userJoined(WebSocketClient client, dynamic data) {
    client.broadcast('user_joined', data);
  }
}

final ChatController chatController = ChatController();
```

Wire it up in your WebSocket route:

```dart
Router.websocket('/ws', (WebSocketEvent event) {
  event.on('message', chatController.newMessage);
  event.on('join', chatController.userJoined);
});
```

## Returning Responses

Controllers should return `Response` objects. See [Responses](responses.md) for all available response types:

```dart
return Response.json({'key': 'value'});
return Response.json({'key': 'value'}, 201);
return Response.html('<h1>Hello</h1>');
return Response.redirect('/login');
return Response.file('report.pdf', bytes);
return Response.download('report.pdf', bytes);
```

## Generating Controllers via CLI

The Vania CLI can scaffold a controller for you:

```bash
vania make:controller post
```

This generates `lib/app/http/controllers/post_controller.dart` with all seven resource methods stubbed out.
