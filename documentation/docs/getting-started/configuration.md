---
sidebar_position: 2
---

# Configuration

Vania splits configuration into two places:

- **`lib/config/app.dart`** — a typed Dart map describing providers, CORS, the database, and other structural settings.
- **`.env`** — plain key/value secrets and per-environment values, read through the `env()` helper.

The rule of thumb: anything that differs between machines or must stay out of source control goes in `.env`; the shape of the app goes in `config/app.dart`.

## The config map

`config/app.dart` exports a `Map<String, dynamic>` that is handed to `Application().initialize(config: config)` at boot:

```dart
import 'package:vania/vania.dart';
import 'package:my_app/app/providers/route_service_provider.dart';
import 'package:my_app/config/cors.dart';

Map<String, dynamic> config = {
  'name': env('APP_NAME', 'Vania'),
  'url': env('APP_URL', 'http://localhost'),
  'cors': cors,
  'providers': <ServiceProvider>[
    RouteServiceProvider(),
  ],
};
```

At boot the framework validates this map, then calls `register()` on every provider and afterwards `boot()` on every provider. `providers` is the one key you will touch most — it is the list of things that wire your app together. `cors` is validated if present.

## Adding a database

To use the ORM, describe your connection(s) under a `database` key and add the `DatabaseServiceProvider`:

```dart
'database': {
  'default': env('DB_CONNECTION', 'mysql'),
  'connections': {
    'mysql': DBConfig(
      driver: 'mysql',
      host: env('DB_HOST', 'localhost'),
      port: env<int>('DB_PORT', 3306),
      database: env('DB_DATABASE', 'my_app'),
      username: env('DB_USERNAME', 'root'),
      password: env('DB_PASSWORD', ''),
      sslMode: env<bool>('DB_SSL_MODE', false),
      pool: env<bool>('DB_POOL', false),
      poolSize: env<int>('DB_POOL_SIZE', 2),
    ),
  },
},
'providers': <ServiceProvider>[
  RouteServiceProvider(),
  DatabaseServiceProvider(),
],
```

`sslMode`, `pool`, and `poolSize` are the connection-pool and TLS switches — note `sslMode` is a boolean, not a string. You can define several named connections and select one with `default`. A plain `Map` is accepted in place of `DBConfig` if you prefer (that is what some of the sample apps use); `DBConfig` just gives you named, typed fields. Remember to register the driver in `bin/server.dart` — see [Installation](installation.md#add-a-database-driver-optional).

## Environment variables

`.env` lives at the project root and is parsed at startup. A typical file:

```env
# Application
APP_NAME=my_app
APP_ENV=local
APP_KEY=a-generated-32-character-minimum-secret
APP_HOST=0.0.0.0
APP_PORT=8000
APP_DEBUG=true
APP_URL=http://localhost:8000

# Storage (local by default; set to s3 for AWS)
STORAGE=local

# Database
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=my_app
DB_USERNAME=root
DB_PASSWORD=secret
DB_SSL_MODE=false
DB_POOL=false
DB_POOL_SIZE=2

# Redis
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASSWORD=

# Mail
MAIL_HOST=smtp.mailtrap.io
MAIL_PORT=587
MAIL_USERNAME=
MAIL_PASSWORD=
MAIL_FROM_ADDRESS=hello@example.com
MAIL_FROM_NAME=MyApp
```

### Reading values

Use `env<T>()` anywhere:

```dart
String name  = env('APP_NAME', 'DefaultApp');
int    port  = env<int>('APP_PORT', 8000);
bool   debug = env<bool>('APP_DEBUG', false);
```

### `APP_ENV` and deployment modes

`APP_ENV` selects one of three deployment modes:

| Value | Meaning |
|-------|---------|
| `local` | A developer machine. Migrations and seeders run freely; GraphiQL and Swagger UI are enabled by default. |
| `staging` | A shared pre-production deployment. Treated as protected. |
| `production` | The live deployment. Protected, and developer-facing tooling is off by default. |

`development`/`dev` are accepted as aliases of `local`, `stage` of `staging`,
and `prod` of `production`. Anything unset or unrecognised is treated as
`production`, so a missing `.env` key fails safe.

On `staging` and `production`, `vania migrate` and `vania migrate:seed` refuse
to run unless you pass `--force` — see
[Migrations](../database/migrations.md#protected-environments).

The second argument is the fallback used when the key is absent. The helper coerces `int`, `double`, `num`, and `bool` from the raw string. System environment variables (`Platform.environment`) are also visible, with `.env` values taking precedence.

## CORS

Cross-origin settings live in `lib/config/cors.dart` as a `CORSConfig`, referenced from the config map's `cors` key:

```dart
import 'package:vania/vania.dart';

CORSConfig cors = CORSConfig(
  enabled: true,
  origin: '*',
  methods: 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  headers: 'Content-Type, Authorization, X-Requested-With',
  exposeHeaders: '',
  credentials: false,
  maxAge: 3600,
);
```

In production, set `origin` to your actual domain(s). Browsers reject `origin: '*'` together with `credentials: true`, so pick one.

A browser sends a cross-origin `QUERY` request only after a preflight that lists it, so add `QUERY` to `methods` if other origins call your [`QUERY` routes](../core/routing.md#query-routes).

## File storage

Storage is chosen by the `STORAGE` environment variable, not the config map. It is `local` by default; set it to `s3` to use AWS S3, and supply the S3 credentials via their own keys:

```env
STORAGE=s3
STORAGE_S3_REGION=us-east-1
STORAGE_S3_BUCKET=my-bucket
STORAGE_S3_ACCESS_KEY=...
STORAGE_S3_SECRET_KEY=...
```

The local driver writes under the project's storage folder. See [Storage](../core/storage.md) for the read/write API.

## HTTPS

To terminate TLS in the app itself, set `APP_SECURE=true` and point the framework at your certificate and key:

```env
APP_SECURE=true
APP_CERTIFICATE=path/to/fullchain.pem
APP_PRIVATE_KEY=path/to/private_key.pem
APP_PRIVATE_KEY_PASSWORD=   # only if the key is encrypted
```

The server then binds with a `SecurityContext` built from those files. In most deployments you will instead terminate TLS at a reverse proxy or load balancer and leave the app on plain HTTP behind it.

## Server tuning

```env
APP_ISOLATES=auto      # isolates serving HTTP: a number, or auto for one per CPU core (default 1)
HTTP_IDLE_TIMEOUT=120  # seconds an idle keep-alive connection is kept; 0 keeps it forever
HTTP_BACKLOG=1024      # connections the OS queues while the server is busy
REQUEST_TIMEOUT=0      # seconds a request may take to start answering before it gets a 503; 0 is off
SHUTDOWN_TIMEOUT=10    # seconds a shutdown waits for in-flight requests
SSE_HEARTBEAT=15       # seconds between keep-alive comments on a quiet event stream
MAX_BODY_SIZE=10485760 # largest request body in bytes, multipart uploads included
```

**`APP_ISOLATES`.** A single isolate runs on a single CPU core. With more than one, each isolate boots the app from the same config and they share the port, so throughput grows with the number of cores. Each isolate has its own memory, though, so anything kept in memory is per isolate:

- **Rate limits** (`Throttle`) count per isolate, so a client gets up to that many times the configured allowance.
- **WebSocket rooms and broadcasts** reach only the clients connected to the same isolate.
- **The session cache** is switched off, and sessions are read from disk on every request so that no isolate serves a stale one.
- Anything your own code keeps in static fields or singletons.

Keep the default of 1 if the app relies on any of these, or move that state somewhere shared, such as Redis.

The extra isolates boot from the config but never run `main()`. Whatever `main()` does before `initialize` — registering a database driver, setting up auth — happens only in the first one, and the others serve without it. Pass that code as `setup`, which runs in every isolate before the providers boot:

```dart
void main(List<String> args) async {
  await Application().initialize(
    config: config,
    args: args,
    setup: () async {
      registerMySqlDriver();
      await AuthServiceProvider().register(/* ... */);
    },
  );
}
```

`setup` is copied to each isolate, so it must not capture anything that cannot be, such as an open connection.

An isolate that exits unexpectedly is replaced. One that keeps dying right after it starts, because its boot fails for instance, is retried less and less often, up to once a minute.

**`HTTP_BACKLOG`** is how many incoming connections wait while the server is busy accepting; a burst beyond it is refused. The OS caps it at its own limit: `net.core.somaxconn` on Linux (usually 4096), `kern.ipc.somaxconn` on macOS (128 unless raised).

**`REQUEST_TIMEOUT`** limits how long the app takes to start answering — a hung database call, say. Once the response has begun, it is left to finish: a stream of server-sent events or a large download is not cut off.

**Shutdown.** On `SIGINT` or `SIGTERM` the server stops accepting connections, lets in-flight requests finish for up to `SHUTDOWN_TIMEOUT`, writes out buffered log entries and exits. A second signal exits at once.

## Reading config at runtime

The `Config` singleton exposes whatever you put in the config map:

```dart
import 'package:vania/vania.dart';

final appName  = Config().get('name');
final database = Config().get('database');
```

## What's next

- [Directory Structure](directory-structure.md) — where each of these files lives.
- [Service Providers](../core/service-providers.md) — how the `providers` list boots your app.
