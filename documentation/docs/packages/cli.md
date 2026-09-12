---
sidebar_position: 11
---

# CLI (vania_cli)

The `vania_cli` package provides command-line tools for project creation, code generation, development server management, database migrations, and production builds.

## Installation

```bash
dart pub global activate vania_cli
```

## Commands

### Project Management

| Command | Description |
|---------|-------------|
| `vania create <name>` | Create a new Vania project |
| `vania serve` | Start the dev server with hot reload |
| `vania serve --host <h> --port <p>` | Bind a specific host/port |
| `vania serve --no-reload` | Restart on change instead of hot reloading |
| `vania down` | Stop the running development server |
| `vania build` | Compile to a native executable |
| `vania update` | Update the CLI to the latest version |
| `vania key:generate` | Generate and write a new `APP_KEY` |
| `vania route:list` | List all registered routes |

### Code Generation

| Command | Description |
|---------|-------------|
| `vania make:controller <name>` | Generate a resource controller |
| `vania make:model <name>` | Generate a model class |
| `vania make:middleware <name>` | Generate a middleware class |
| `vania make:migration <name>` | Generate a migration file |
| `vania make:provider <name>` | Generate a service provider |
| `vania make:mail <name>` | Generate a mailable class |
| `vania make:seeder <name>` | Generate a database seeder |
| `vania make:auth` | Generate the personal access tokens migration |

### Database

| Command | Description |
|---------|-------------|
| `vania migrate` | Run pending migrations |
| `vania migrate:fresh` | Drop all tables and re-run migrations |
| `vania migrate:seed` | Run database seeders |

## Creating a Project

```bash
vania create my_blog
cd my_blog
```

This clones the official template, sets up the project name, generates an `.env` file, and installs dependencies.

## Development Server

```bash
vania serve
```

The server watches for `.dart` file changes and automatically restarts. Output shows the URL where your application is running.

To stop:

```bash
vania down
```

Or press `Ctrl+C` in the terminal.

## Code Generation Examples

### Controller

```bash
vania make:controller post
```

Generates `lib/app/http/controllers/post_controller.dart`:

```dart
class PostController extends Controller {
  Future<Response> index() async {
    return Response.json({});
  }

  Future<Response> create() async {
    return Response.json({});
  }

  Future<Response> store(Request req) async {
    return Response.json({});
  }

  Future<Response> show(int id) async {
    return Response.json({});
  }

  Future<Response> edit(int id) async {
    return Response.json({});
  }

  Future<Response> update(Request req, int id) async {
    return Response.json({});
  }

  Future<Response> destroy(int id) async {
    return Response.json({});
  }
}

final PostController postController = PostController();
```

### Model

```bash
vania make:model post
```

Generates `lib/app/models/post.dart`:

```dart
class Post extends Model {
  Post() {
    super.table('posts');
  }
}
```

### Migration

```bash
vania make:migration create_posts_table
```

Generates a timestamped migration file and adds it to the migration registry.

### Service Provider

```bash
vania make:provider cache
```

Generates `lib/app/providers/cache_service_provider.dart` with `register()` and `boot()` stubs.

## Production Build

```bash
vania build
```

Compiles `bin/server.dart` to a native executable at `bin/server`. The resulting binary is self-contained — it runs without the Dart SDK on the target machine.

Deploy the binary along with your `.env`, `public/`, and `storage/` directories.
