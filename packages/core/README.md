# Vania

**A batteries-included backend framework for Dart — expressive to write, and fast because it's Dart.**

Vania is the core of the framework. It runs the HTTP server, routes requests, moves them through a middleware pipeline, hands them to your controllers, and sends responses back. On top of that it gives you an ORM, migrations, validation, sessions, caching, mail, an IoC container, and configuration — the whole toolbox you need to ship a real API server, in one package.

It does **not** ship a database client. That's on purpose. You pick a driver (`vania_mysql`, `vania_postgresql`, or `vania_mongodb`) and register it in one line; the rest of your code talks to the same `package:vania/database.dart` API no matter which database is underneath. Switching databases later is a config change, not a rewrite.

## Install

```yaml
dependencies:
  vania: ^2.0.0
```

The fastest way to start a project is the companion CLI:

```bash
dart pub global activate vania_cli
vania create blog
cd blog
vania serve
```

Your server is running on `http://localhost:8000`.

## A first route

```dart
import 'package:vania/http/response.dart';
import 'package:vania/route.dart';

Router.get('/health', () => Response.json({'status': 'ok'}));
Router.post('/users/{id}', userController.update).whereInt('id');
```

Routes can be named, grouped, constrained, and wrapped in middleware. Controllers stay thin: read the request, do the work, return a `Response`.

## What's in the box

| Area | What you get |
| --- | --- |
| **Routing** | Named routes, groups, prefixes, parameter constraints, resource routes |
| **Requests & responses** | Typed input access, uploaded files, JSON/HTML/file/SSE responses |
| **Middleware** | A simple `handle` / `process` pipeline; throw to reject |
| **Validation** | String rules, fluent rules, form-request classes, custom rules |
| **ORM & query builder** | Models, relations, eager loading, a fluent query builder |
| **Migrations & seeders** | Schema builder, versioned migrations, factories |
| **Sessions** | Encrypted file sessions, CSRF protection |
| **Caching** | Driver-based cache (file built in; Redis via `vania_redis`) |
| **Mail** | Mailables with envelopes, content, and view templates |
| **IoC container** | Constructor-free service resolution used throughout the framework |

## The database stays driver-agnostic

`package:vania/database.dart` owns everything portable — the query builder, models, relations, migrations, seeders. A driver package plugs in the actual connection:

| Driver package | Registered names |
| --- | --- |
| `vania_mysql` | `mysql`, `mariadb` |
| `vania_postgresql` | `pgsql`, `postgres`, `postgresql` |
| `vania_mongodb` | `mongodb`, `mongo` |

```dart
final users = await DB.table('users')
    .where('active', '=', true)
    .orderBy('created_at', 'desc')
    .get();
```

## Companion packages

Everything beyond the core is optional and installed only when you need it: authentication, Redis, Elasticsearch, GraphQL, gRPC, Swagger/OpenAPI, and real-time WebSockets. Each lives in its own package with its own README, and none of them is required to run a Vania app.

## Links

- Documentation: [vdart.dev/docs](https://vdart.dev/docs/intro)
- Source & issues: [github.com/vania-dart/framework](https://github.com/vania-dart/framework)

## License

MIT
