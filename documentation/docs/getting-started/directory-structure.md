---
sidebar_position: 3
---

# Directory Structure

`vania create` clones the official starter template, so a new project looks roughly like the layout below. The exact set of sample files evolves with the template, but the folder conventions — and how the framework finds your code — are stable, and that is what this page explains.

```
my_app/
├── bin/
│   └── server.dart                 # Application entry point
├── lib/
│   ├── config/
│   │   ├── app.dart                # Master configuration map
│   │   ├── auth.dart               # Authentication guard config
│   │   └── cors.dart               # CORS settings
│   ├── route/
│   │   ├── api_route.dart          # API routes (prefixed with /api)
│   │   ├── web.dart                # Web routes (HTML responses)
│   │   └── web_socket.dart         # WebSocket routes
│   ├── app/
│   │   ├── providers/
│   │   │   └── route_service_provider.dart
│   │   ├── http/
│   │   │   ├── controllers/
│   │   │   │   └── home_controller.dart
│   │   │   └── middleware/
│   │   │       ├── authenticate.dart
│   │   │       └── error_response_middleware.dart
│   │   └── models/
│   │       └── user.dart
│   └── database/
│       └── migrations/
│           ├── create_user_table.dart
│           └── migrate.dart        # Migration registry
├── public/                         # Static files served directly
├── storage/
│   └── app/                        # Application file storage
├── .env                            # Environment configuration
├── pubspec.yaml
├── Dockerfile
└── docker-compose.yml
```

## Key Directories

### `bin/`

Contains the executable entry point. `server.dart` creates the `Application` instance and passes your configuration to it. This is the only file that should import a database driver registration function.

### `lib/config/`

Holds configuration files. The main `app.dart` exports a `Map<String, dynamic>` that defines providers, CORS, auth, database connections, and other application-wide settings.

### `lib/route/`

Route definitions are organized by concern. Each route file is a class that implements `Route` and registers paths in its `register()` method. The convention is:

- **`web.dart`** — routes that return HTML, with session and CSRF protection.
- **`api_route.dart`** — stateless JSON API routes, typically prefixed with `/api`.
- **`web_socket.dart`** — WebSocket endpoint registrations.

### `lib/app/providers/`

Service providers are classes that extend `ServiceProvider`. The `RouteServiceProvider` is responsible for calling `register()` on all route files. You can add your own providers here for database, cache, or custom services.

### `lib/app/http/controllers/`

Controllers hold your request handling logic. Each controller extends `Controller` and defines methods that accept a `Request` and return a `Response`.

### `lib/app/http/middleware/`

Middleware classes extend `Middleware` and implement a `handle(Request req)` method. They can inspect or modify the request before it reaches the controller, or short-circuit the response entirely.

### `lib/app/models/`

ORM models extend `Model`. Each model maps to a database table. Models define their table name, primary key, timestamps, fillable fields, relations, and other ORM behavior.

### `lib/database/migrations/`

Each migration is a class extending `Migration` with `up()` and `down()` methods. The `migrate.dart` file is the runner that registers and executes all migrations in order.

### `public/`

Static assets (CSS, JavaScript, images) placed here are served directly by the framework without hitting the router.

### `storage/`

The `storage/app/` directory is the default location for file uploads and application-generated files. The framework also uses `storage/framework/sessions/` for file-based sessions and `storage/framework/cache/` for the file cache driver.

### `.env`

Environment-specific settings that should not be committed to version control. Contains database credentials, API keys, and feature flags. See [Configuration](configuration.md) for all available keys.

## Recommended Additions

As your project grows, you will typically add:

```
lib/
├── app/
│   ├── http/
│   │   └── controllers/
│   │       ├── auth_controller.dart
│   │       ├── post_controller.dart
│   │       └── ...
│   ├── models/
│   │   ├── post.dart
│   │   ├── comment.dart
│   │   └── ...
│   └── services/               # Business logic layer
│       ├── post_service.dart
│       └── ...
├── database/
│   ├── migrations/
│   │   ├── create_posts_table.dart
│   │   └── ...
│   └── seeders/
│       ├── user_seeder.dart
│       └── ...
```

For larger applications, see the [Architecture](../architecture/modular.md) guides for alternative project structures.
