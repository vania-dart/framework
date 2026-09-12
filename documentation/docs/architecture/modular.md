---
sidebar_position: 1
---

# Modular Architecture

A modular architecture groups code by feature rather than by technical role. Each module is a self-contained unit with its own controllers, models, routes, and services. This is a good starting point for medium-sized applications that might grow into larger systems.

## Directory Structure

```
my_app/
├── bin/
│   └── server.dart
├── lib/
│   ├── config/
│   │   ├── app.dart
│   │   ├── auth.dart
│   │   ├── cors.dart
│   │   └── database.dart
│   ├── modules/
│   │   ├── auth/
│   │   │   ├── auth_controller.dart
│   │   │   ├── auth_routes.dart
│   │   │   ├── auth_middleware.dart
│   │   │   └── auth_service.dart
│   │   ├── user/
│   │   │   ├── user_controller.dart
│   │   │   ├── user_model.dart
│   │   │   ├── user_routes.dart
│   │   │   ├── user_service.dart
│   │   │   └── user_validation.dart
│   │   ├── post/
│   │   │   ├── post_controller.dart
│   │   │   ├── post_model.dart
│   │   │   ├── post_routes.dart
│   │   │   ├── post_service.dart
│   │   │   └── comment/
│   │   │       ├── comment_controller.dart
│   │   │       ├── comment_model.dart
│   │   │       └── comment_service.dart
│   │   └── notification/
│   │       ├── notification_controller.dart
│   │       ├── notification_model.dart
│   │       ├── notification_routes.dart
│   │       └── notification_service.dart
│   ├── shared/
│   │   ├── middleware/
│   │   │   ├── rate_limit_middleware.dart
│   │   │   └── cors_middleware.dart
│   │   ├── services/
│   │   │   ├── mail_service.dart
│   │   │   └── cache_service.dart
│   │   └── helpers/
│   │       └── pagination_helper.dart
│   ├── database/
│   │   ├── migrations/
│   │   │   ├── create_users_table.dart
│   │   │   ├── create_posts_table.dart
│   │   │   └── migrate.dart
│   │   └── seeders/
│   │       ├── user_seeder.dart
│   │       └── post_seeder.dart
│   └── providers/
│       ├── route_service_provider.dart
│       └── app_service_provider.dart
├── public/
├── storage/
├── test/
│   ├── modules/
│   │   ├── auth/
│   │   │   └── auth_controller_test.dart
│   │   ├── user/
│   │   │   └── user_service_test.dart
│   │   └── post/
│   │       └── post_controller_test.dart
│   └── shared/
│       └── helpers/
│           └── pagination_test.dart
└── .env
```

## How It Works

### Module Structure

Each module contains everything it needs:

```dart
// lib/modules/post/post_routes.dart
import 'package:vania/vania.dart';
import 'post_controller.dart';

class PostRoutes implements Route {
  @override
  void register() {
    Router.resource('/posts', postController);
    Router.get('/posts/{id}/comments', postController.comments)
        .whereInt('id');
  }
}
```

```dart
// lib/modules/post/post_controller.dart
import 'package:vania/vania.dart';
import 'package:vania/http/controller.dart';
import 'package:vania/http/request.dart';
import 'package:vania/http/response.dart';
import 'post_service.dart';

class PostController extends Controller {
  final _service = PostService();

  Future<Response> index() async {
    return Response.json(await _service.getAllPosts());
  }

  Future<Response> store(Request req) async {
    req.validate({
      'title': 'required|string|max_length:255',
      'body': 'required|string',
    });
    return Response.json(
      await _service.createPost(req.only(['title', 'body'])),
      201,
    );
  }

  // ... show, update, destroy
}

final PostController postController = PostController();
```

```dart
// lib/modules/post/post_service.dart
import 'post_model.dart';

class PostService {
  Future<List<Map<String, dynamic>>> getAllPosts() async {
    return await Post().query.orderByDesc('created_at').get();
  }

  Future<Map<String, dynamic>> createPost(Map<String, dynamic> data) async {
    return await Post().query.create(data);
  }
}
```

### Route Registration

The `RouteServiceProvider` pulls in routes from each module:

```dart
class RouteServiceProvider extends ServiceProvider {
  @override
  Future<void> register() async {
    Router.basePrefix('api');
    AuthRoutes().register();
    UserRoutes().register();
    PostRoutes().register();
    NotificationRoutes().register();
  }

  @override
  Future<void> boot() async {}
}
```

### Shared Code

Cross-cutting concerns (middleware, helpers, generic services) live in `shared/`. Modules can import from shared but should not import from each other — if two modules need to communicate, introduce a shared service or event.

## When to Use This

- Your application has 5–20 distinct features.
- Multiple developers work on different features simultaneously.
- You want feature isolation without the overhead of separate packages.
- You might extract modules into microservices later.

## Key Principles

1. **One directory per feature.** Controllers, models, services, and routes for a feature live together.
2. **No cross-module imports.** Modules communicate through shared services or the database.
3. **Tests mirror modules.** Each module has a corresponding test directory.
4. **Database stays centralized.** Migrations and seeders live in one place because they affect the shared database.
