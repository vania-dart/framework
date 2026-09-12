---
sidebar_position: 1
---

# Tutorial: Build a Blog API

This tutorial walks through building a complete blog REST API with posts, comments, and user authentication. By the end, you will have endpoints for registering users, managing posts, and adding comments — all with validation, pagination, and auth protection.

## 1. Create the Project

```bash
vania create blog_api
cd blog_api
dart pub add vania_mysql vania_auth
dart pub get
```

## 2. Configure the Database

Edit `.env`:

```env
APP_NAME=blog_api
APP_KEY=your-32-character-key-goes-here-ok
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=blog_api
DB_USERNAME=root
DB_PASSWORD=secret
```

Create the database:

```sql
CREATE DATABASE blog_api;
```

## 3. Set Up the Entry Point

```dart
// bin/server.dart
import 'package:vania/vania.dart';
import 'package:vania_mysql/vania_mysql.dart';
import 'package:vania_auth/vania_auth.dart';
import 'package:blog_api/config/app.dart';
import 'package:blog_api/app/models/user.dart';

void main() async {
  registerMySqlDriver();

  await AuthServiceProvider().register(
    jwtSecretKey: env('APP_KEY'),
    tokenStore: ModelPersonalAccessTokenStore(model: PersonalAccessToken()),
    userProvider: ModelUserProvider(model: User()),
  );

  await Application().initialize(config: config);
}
```

Update `lib/config/app.dart` to include the database provider:

```dart
import 'package:vania/vania.dart';
import 'package:vania/database.dart';
import 'package:blog_api/app/providers/route_service_provider.dart';

Map<String, dynamic> config = {
  'name': env('APP_NAME', 'blog_api'),
  'url': env('APP_URL', 'http://localhost'),
  'database': {
    'default': env('DB_CONNECTION', 'mysql'),
    'connections': {
      'mysql': DBConfig(
        driver: 'mysql',
        host: env('DB_HOST', 'localhost'),
        port: env<int>('DB_PORT', 3306),
        database: env('DB_DATABASE', 'blog_api'),
        username: env('DB_USERNAME', 'root'),
        password: env('DB_PASSWORD', ''),
      ),
    },
  },
  'providers': [
    RouteServiceProvider(),
    DatabaseServiceProvider(),
  ],
};
```

## 4. Create Migrations

### Users Table

```bash
vania make:migration create_users_table
```

```dart
class CreateUsersTable extends Migration {
  @override
  Future<void> up() async {
    await create('users', (Schema schema) {
      schema.id();
      schema.string('name', length: 100);
      schema.string('email', length: 255).unique();
      schema.string('password', length: 255);
      schema.timeStamps();
    }, true);
  }

  @override
  Future<void> down() async {
    await drop('users');
  }
}
```

### Personal Access Tokens Table

```bash
vania make:auth
```

### Posts Table

```bash
vania make:migration create_posts_table
```

```dart
class CreatePostsTable extends Migration {
  @override
  Future<void> up() async {
    await create('posts', (Schema schema) {
      schema.id();
      schema.integer('user_id').unsigned().foreignKey('users', 'id', onDelete: 'CASCADE');
      schema.string('title', length: 255);
      schema.string('slug', length: 255).unique();
      schema.text('body');
      schema.boolean('published').defaultTo(false);
      schema.dateTime('published_at').nullable();
      schema.timeStamps();
      schema.softDeletes();
    }, true);
  }

  @override
  Future<void> down() async {
    await drop('posts');
  }
}
```

### Comments Table

```bash
vania make:migration create_comments_table
```

```dart
class CreateCommentsTable extends Migration {
  @override
  Future<void> up() async {
    await create('comments', (Schema schema) {
      schema.id();
      schema.integer('post_id').unsigned().foreignKey('posts', 'id', onDelete: 'CASCADE');
      schema.integer('user_id').unsigned().foreignKey('users', 'id', onDelete: 'CASCADE');
      schema.text('body');
      schema.timeStamps();
    }, true);
  }

  @override
  Future<void> down() async {
    await drop('comments');
  }
}
```

Run all migrations:

```bash
vania migrate
```

## 5. Create Models

```dart
// lib/app/models/user.dart
import 'package:vania/database.dart';

class User extends Model {
  @override
  List<String> get fillable => ['name', 'email', 'password'];
  @override
  List<String> get hidden => ['password'];

  @override
  void registerRelations() {
    hasMany('posts', Post(), foreignKey: 'user_id');
    hasMany('comments', Comment(), foreignKey: 'user_id');
  }
}

// lib/app/models/post.dart
import 'package:vania/database.dart';

class Post extends Model {
  @override
  List<String> get fillable => ['user_id', 'title', 'slug', 'body', 'published', 'published_at'];
  @override
  bool get softDeletes => true;

  @override
  void registerRelations() {
    belongsTo('user', User(), foreignKey: 'user_id');
    hasMany('comments', Comment(), foreignKey: 'post_id');
  }
}

// lib/app/models/comment.dart
import 'package:vania/database.dart';

class Comment extends Model {
  @override
  List<String> get fillable => ['post_id', 'user_id', 'body'];

  @override
  void registerRelations() {
    belongsTo('user', User(), foreignKey: 'user_id');
    belongsTo('post', Post(), foreignKey: 'post_id');
  }
}
```

## 6. Create Controllers

### Auth Controller

```dart
// lib/app/http/controllers/auth_controller.dart
import 'package:vania/vania.dart';
import 'package:vania/http/controller.dart';
import 'package:vania/http/request.dart';
import 'package:vania/http/response.dart';
import 'package:vania_auth/vania_auth.dart';
import 'package:blog_api/app/models/user.dart';

class AuthController extends Controller {
  Future<Response> register(Request req) async {
    req.validate({
      'name': 'required|string|max_length:100',
      'email': 'required|email|unique:users',
      'password': 'required|min_length:8|confirmed',
    });

    final user = await User().query.create({
      'name': req.input('name'),
      'email': req.input('email'),
      'password': Auth().hash.make(req.input('password')),
    });

    Auth().login(user);
    final token = await Auth().createToken(expiresIn: Duration(days: 30));

    return Response.json({
      'user': user,
      'token': token['access_token'],
    }, 201);
  }

  Future<Response> login(Request req) async {
    req.validate({
      'email': 'required|email',
      'password': 'required',
    });

    final user = await User().query.firstWhere('email', '=', req.input('email'));

    if (user == null || !Auth().hash.verify(req.input('password'), user['password'])) {
      return Response.json({'message': 'Invalid credentials'}, 401);
    }

    Auth().login(user);
    final token = await Auth().createToken(expiresIn: Duration(days: 30));

    return Response.json({
      'user': user,
      'token': token['access_token'],
    });
  }

  Future<Response> me(Request req) async {
    return Response.json(req.user);
  }

  Future<Response> logout(Request req) async {
    final token = req.header('authorization')?.replaceFirst('Bearer ', '');
    if (token != null) await Auth().revokeToken(token);
    return Response.json({'message': 'Logged out'});
  }
}

final AuthController authController = AuthController();
```

### Post Controller

```dart
// lib/app/http/controllers/post_controller.dart
import 'package:vania/vania.dart';
import 'package:vania/http/controller.dart';
import 'package:vania/http/request.dart';
import 'package:vania/http/response.dart';
import 'package:blog_api/app/models/post.dart';

class PostController extends Controller {
  Future<Response> index() async {
    final posts = await Post().query
        .where('published', '=', true)
        .include('user:id,name')
        .orderByDesc('published_at')
        .paginate(perPage: 15);
    return Response.json(posts);
  }

  Future<Response> show(int id) async {
    final post = await Post().query
        .include('user:id,name')
        .include('comments')
        .findOrFail(id);
    return Response.json(post);
  }

  Future<Response> store(Request req) async {
    req.validate({
      'title': 'required|string|max_length:255',
      'body': 'required|string',
    });

    final title = req.input('title') as String;
    final slug = title.toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');

    final post = await Post().query.create({
      'user_id': req.user?['id'],
      'title': title,
      'slug': slug,
      'body': req.input('body'),
      'published': false,
    });

    return Response.json(post, 201);
  }

  Future<Response> update(Request req, int id) async {
    req.validate({
      'title': 'required|string|max_length:255',
      'body': 'required|string',
    });

    await Post().query.where('id', '=', id).where('user_id', '=', req.user?['id']).update({
      'title': req.input('title'),
      'body': req.input('body'),
    });

    return Response.json({'message': 'Updated'});
  }

  Future<Response> publish(int id) async {
    await Post().query.where('id', '=', id).update({
      'published': true,
      'published_at': DateTime.now().toIso8601String(),
    });
    return Response.json({'message': 'Published'});
  }

  Future<Response> destroy(int id) async {
    await Post().query.where('id', '=', id).delete();
    return Response.json({'message': 'Deleted'});
  }
}

final PostController postController = PostController();
```

### Comment Controller

```dart
// lib/app/http/controllers/comment_controller.dart
import 'package:vania/vania.dart';
import 'package:vania/http/controller.dart';
import 'package:vania/http/request.dart';
import 'package:vania/http/response.dart';
import 'package:blog_api/app/models/comment.dart';

class CommentController extends Controller {
  Future<Response> index(int postId) async {
    final comments = await Comment().query
        .where('post_id', '=', postId)
        .include('user:id,name')
        .orderByDesc('created_at')
        .get();
    return Response.json(comments);
  }

  Future<Response> store(Request req, int postId) async {
    req.validate({'body': 'required|string'});

    final comment = await Comment().query.create({
      'post_id': postId,
      'user_id': req.user?['id'],
      'body': req.input('body'),
    });

    return Response.json(comment, 201);
  }

  Future<Response> destroy(int postId, int id) async {
    await Comment().query
        .where('id', '=', id)
        .where('post_id', '=', postId)
        .delete();
    return Response.json({'message': 'Deleted'});
  }
}

final CommentController commentController = CommentController();
```

## 7. Define Routes

```dart
// lib/route/api_route.dart
import 'package:vania/vania.dart';
import 'package:vania_auth/vania_auth.dart';
import 'package:blog_api/app/http/controllers/auth_controller.dart';
import 'package:blog_api/app/http/controllers/post_controller.dart';
import 'package:blog_api/app/http/controllers/comment_controller.dart';

class ApiRoute implements Route {
  @override
  void register() {
    Router.basePrefix('api');

    // Public
    Router.post('/register', authController.register);
    Router.post('/login', authController.login);
    Router.get('/posts', postController.index);
    Router.get('/posts/{id}', postController.show).whereInt('id');
    Router.get('/posts/{postId}/comments', commentController.index).whereInt('postId');

    // Protected
    Router.group(() {
      Router.get('/me', authController.me);
      Router.post('/logout', authController.logout);

      Router.post('/posts', postController.store);
      Router.put('/posts/{id}', postController.update).whereInt('id');
      Router.patch('/posts/{id}/publish', postController.publish).whereInt('id');
      Router.delete('/posts/{id}', postController.destroy).whereInt('id');

      Router.post('/posts/{postId}/comments', commentController.store).whereInt('postId');
      Router.delete('/posts/{postId}/comments/{id}', commentController.destroy);
    }, middleware: [Authenticate()]);
  }
}
```

## 8. Test It

Start the server:

```bash
vania serve
```

Register a user:

```bash
curl -X POST http://localhost:8000/api/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Alice","email":"alice@example.com","password":"secret123","password_confirmation":"secret123"}'
```

Create a post (use the token from registration):

```bash
curl -X POST http://localhost:8000/api/posts \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"title":"My First Post","body":"Hello from Vania!"}'
```

List posts:

```bash
curl http://localhost:8000/api/posts
```

You now have a fully functional blog API with authentication, CRUD operations, soft deletes, pagination, and eager-loaded relationships.
