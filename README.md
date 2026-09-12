<p align="center">
  <img src="packages/core/assets/logo.png" height="120" alt="Vania" />
</p>

<h1 align="center">Vania</h1>

<p align="center">
  A fast, simple, and unapologetically batteries-included backend framework for Dart.
</p>

<p align="center">
  <a href="https://pub.dev/packages/vania"><img src="https://img.shields.io/pub/v/vania.svg" alt="pub package"></a>
  <a href="https://vdart.dev/docs"><img src="https://img.shields.io/badge/docs-vdart.dev-blue.svg" alt="docs"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-purple.svg" alt="license"></a>
</p>

---

Dart is a great language for writing servers — it's fast, it AOT-compiles to a single
binary, and if you already ship Flutter you know it. What it has been missing is the
boring, unglamorous infrastructure every real backend ends up needing: routing,
validation, an ORM, migrations, auth, sessions, a job of a CLI to tie it all together.

Vania is that infrastructure. If you've written Laravel, most of it will feel familiar.
If you haven't, it should still feel obvious.

## Quick start

```bash
dart pub global activate vania_cli
vania create my_api
cd my_api
vania serve
```

Your server is on `http://localhost:8000`, and `vania serve` reloads it whenever you
save a Dart file.

## What an app looks like

A route file:

```dart
import 'package:vania/route.dart';

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
```

A controller:

```dart
class TodoController extends Controller {
  Future<Response> store(Request req) async {
    await req.validate({'title': 'required|string|max_length:255'});

    final todo = await Todo().query().insertGetId({
      'title': req.input('title'),
    });

    return Response.json(todo, 201);
  }
}
```

And the entrypoint, which is the whole bootstrap:

```dart
void main(List<String> args) async {
  await Application().initialize(config: config);
}
```

## The database layer

Vania's ORM, query builder, migrations, seeders, and relations all live in the core
package. Drivers are thin — they translate the shared contract to a real connection and
nothing more. In practice that means your application code imports one thing:

```dart
import 'package:vania/database.dart';
```

and the driver name appears exactly once, in `main.dart`:

```dart
registerMysqlDriver();   // or registerPostgresqlDriver() / registerMongodbDriver()
```

Swapping MySQL for PostgreSQL is a one-line change. Models, relations
(`hasMany`, `belongsTo`, `belongsToMany`, and the full morph family), migrations, and
query-builder calls come along unchanged, because none of them ever belonged to the
driver in the first place.

```dart
final users = await User()
    .query()
    .where('active', '=', true)
    .orderBy('created_at', 'desc')
    .paginate(perPage: 20);
```

## Packages

Core ships what every server needs. Everything else is opt-in — add the package, register
its provider, done.

| Package | What it gives you |
| --- | --- |
| [`vania`](packages/core) | HTTP server, router, middleware, validation, ORM, migrations, sessions, views, mail |
| [`vania_cli`](packages/vania_cli) | Project scaffolding, generators, migrations, `serve`, `build` |
| [`vania_mysql`](packages/vania_mysql) | MySQL driver |
| [`vania_postgresql`](packages/vania_postgresql) | PostgreSQL driver |
| [`vania_mongodb`](packages/vania_mongodb) | MongoDB driver and document query builder |
| [`vania_auth`](packages/vania_auth) | JWT and personal access tokens, guards, hashing, revocation |
| [`vania_redis`](packages/vania_redis) | Redis client, cache driver, pub/sub, Lua scripting, pooling |
| [`vania_websocket`](packages/vania_websocket) | WebSockets with channels, rooms, presence, broadcasting |
| [`vania_graphql`](packages/vania_graphql) | GraphQL execution, HTTP transport, subscriptions |
| [`vania_grpc`](packages/vania_grpc) | gRPC server and client |
| [`vania_swagger`](packages/vania_swagger) | OpenAPI 3.0 generation and Swagger UI |
| [`vania_elasticsearch`](packages/vania_elasticsearch) | Elasticsearch client, query builder, bulk indexing |

## CLI

```
vania create <name>          Create a new project
vania serve                  Run with hot reload
vania build                  Compile to a native executable
vania route:list             List registered routes
vania key:generate           Generate APP_KEY into .env

vania make:controller        vania make:model
vania make:middleware        vania make:provider
vania make:migration         vania make:migration-alter
vania make:mail              vania make:auth

vania migrate                Run pending migrations
vania migrate:seed           Run seeders
vania db:seed                Create and register a seeder
```

## Examples

Runnable projects, smallest first:

- [counter](examples/counter) — the smallest thing that serves a request
- [todos](examples/todos) — a feature-modular REST API
- [basic_authentication](examples/basic_authentication) — tokens, guards, protected routes
- [ddd_wallet](examples/ddd_wallet) — domain-driven layering on a real schema
- [websocket_chat](examples/websocket_chat) · [graphql_api](examples/graphql_api) · [grpc_greeter](examples/grpc_greeter)
- [swagger_api](examples/swagger_api) · [redis_cache](examples/redis_cache) · [elasticsearch_search](examples/elasticsearch_search)

## Documentation

Full docs live at **[vdart.dev/docs](https://vdart.dev/docs)**. The source is in
[`docs/`](docs) — start with [installation](docs/getting-started/installation.md),
then [directory structure](docs/getting-started/directory-structure.md) and
[configuration](docs/getting-started/configuration.md).

## Contributing

Issues and pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). If you're
fixing a bug, a failing test that reproduces it is the fastest way to get the fix merged.

## License

MIT © Vania contributors — see [LICENSE](LICENSE).
