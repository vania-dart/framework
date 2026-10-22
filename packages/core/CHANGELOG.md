## 2.1.0

This release is mostly about the HTTP layer: what happens between a request
arriving and the response leaving. It is faster, it no longer falls over when
a handler misbehaves, and a few long-standing bugs around CSRF, sessions and
flash messages are gone. It also adds the new HTTP `QUERY` method.

Vania is API-first, and this release leans into that: JSON with a real status
code is the default everywhere, and redirects or HTML pages only happen when
the app actually has views or asks for them.

### Things that behave differently

- **The response is written after the middleware chain.** Your controller
  returns a `Response` and Vania writes it once every middleware is done, so
  a middleware can still add headers after `await next()`. If the controller
  throws, the error now comes back out of `await next()` where a middleware
  can see it. Calling `next()` twice throws a `StateError` instead of running
  the controller a second time.
- **Errors get one answer, wherever they're thrown.** Throwing from a
  middleware or from a controller gives the same response. An app with no
  views answers in JSON even if a browser asks for HTML. The message of a 5xx
  is only shown when `APP_DEBUG` is on. `Unauthenticated` only redirects to a
  login page when you create it with `responseType: ResponseType.html`;
  otherwise it's a plain 401.
- **`where()` matches the whole segment.** `r'\d+'` used to accept `abc123`;
  it doesn't anymore. `whereString`, `whereDouble` and `whereBool` are
  actually enforced now, and the controller gets the declared type.
- **Paths are decoded before matching.** Route parameters reach the
  controller decoded (`سلام دنیا`, not `%D8%B3...`), and a route written in
  Persian or any other script matches.
- **CSRF** runs before any other middleware and now covers `DELETE` too. An
  entry in `csrf_except` covers that path and what's under it, so `webhooks`
  no longer accidentally covers `webhooks-admin`. A `.` in a wildcard pattern
  means a literal dot.
- **Sessions.** A session id the server never handed out is ignored instead
  of adopted, by page requests and API calls alike. The stored session lives for `SESSION_LIFETIME` (it used to be
  a fixed hour) and gets extended once it's past half of that. Changes are
  saved once, right before the response, and only the keys that changed are
  written.
- `Router.any(...).middleware(...)` (and `.where()`, `.name()` and friends)
  now applies to every method `any` registered, not just the last one. Inside
  a group, `any` also picks up the group's prefix.
- A response whose data can't be encoded as JSON is a 500, not a 200 with a
  broken body. `Response()` with no data sends an empty body instead of
  `null`.
- **`Throttle` no longer turns itself off in development** unless you ask
  with `bypassInDevelopment: true`; then it's skipped while `APP_ENV` is
  `local` or `development`. A production app running on a `.env` copied
  from a laptop kept no rate limits before.
- `env<int>`, `env<bool>` and the other typed reads treat an empty value
  (`KEY=`) as not set and return your default.
- `ROUTE_LOOK_UP_SIZE` is gone, along with the route cache it sized. Route
  lookup is indexed now and doesn't need it.

### New

- Serve from several isolates with `APP_ISOLATES` (a number, or `auto`). If
  one crashes, a new one takes its place. The extra isolates don't run
  `main()`, so move what you do there before `initialize` — registering a
  database driver, setting up auth — into the new `setup:` callback, which
  runs in every isolate:

  ```dart
  await Application().initialize(
    config: config,
    setup: () => registerMySqlDriver(),
  );
  ```
- Graceful shutdown on `SIGINT`/`SIGTERM`: requests in flight get up to
  `SHUTDOWN_TIMEOUT` seconds to finish.
- `REQUEST_TIMEOUT`, `HTTP_IDLE_TIMEOUT` and `HTTP_BACKLOG` settings.
- The HTTP `QUERY` method (RFC 10008): `Router.query(...)`,
  `.acceptQuery([...])` to say which content types a route takes, the
  `Accept-Query` header, and an `Allow` header on `OPTIONS`.
- `HEAD` requests are answered by the matching `GET` route.
- `Request.rawBody` for bodies that aren't JSON or forms.
- `Response.fromPath(...)` streams a file from disk and supports `Range`, so
  large downloads and video seeking don't load the file into memory.
- `Router.apiResource(...)`: a resource without the `create`/`edit` form
  pages.
- `regenerateSession()` to give a session a new id, e.g. right after login.
- `Logger.flush()`.
- Server-sent events are actually delivered as they happen now, with a
  heartbeat (`SSE_HEARTBEAT`), and the stream is cancelled when the client
  goes away.

### Fixed

- An error thrown after the response had started could take the whole server
  down. It doesn't anymore, and neither does a stray future that fails with
  nobody awaiting it.
- With CSRF protection on, every `POST` was rejected because the cookie was
  read before it was parsed.
- Flash messages, validation errors and old input now survive the redirect.
- HTML error responses and the `errors/*.html` pages are sent with the real
  error status instead of 200.
- Downloads with a non-ASCII name (`گزارش.pdf`) failed with a 500. They now
  use `filename*` so browsers save them under the right name.
- Static files with spaces or non-Latin letters in their name weren't found.
- `MAX_BODY_SIZE` is enforced for chunked multipart uploads as well.
- Session files are written atomically, and a damaged one is treated as no
  session rather than an error.
- `Response.back()` only follows a same-site `Referer` and no longer loops on
  `GET`.
- `Request.has`, `except`, `headers`, `file` and `files` misbehaved on some
  inputs.
- `Throttle` reports `X-RateLimit-Remaining` after counting the request and
  sends the real reset time.
- Two routes with the same path, one for a domain and one for any host,
  overwrote each other; now both work and the host decides. An encoded `/`
  (`a%2Fb`) no longer finds the static route `a/b`.
- The `XSRF-TOKEN` cookie expired after a fixed 2.5 hours, so a form left
  open longer got a 419 while its session was still alive. It now lasts as
  long as the session and is renewed with it.
- A server isolate that keeps failing to start is retried at most once a
  minute, instead of the wait starting over at one second.
- A middleware that neither calls `next()` nor returns a response now gets a
  500 instead of leaving the request hanging.
- A `Router.group` callback that throws no longer leaks its prefix and
  middleware into the routes registered after it.

## 2.0.0

Vania 2.0 makes the framework driver-agnostic. Everything portable — the ORM,
the query builder, migrations, seeders — now lives in `vania` itself, and the
database packages are thin adapters you swap in one line. Authentication moved
out to `vania_auth`, WebSockets share the app's single HTTP port, and
migrations refuse to touch a production database by accident.

### Breaking changes

- **Database code lives in core.** `Model`, `QueryBuilder`, `DB`, relations,
  `Migration`, `Schema`, `Seeder`, `DBConfig`, and `PaginatedResult` are all
  exported from `package:vania/database.dart`. The driver packages
  (`vania_mysql`, `vania_postgresql`, `vania_mongodb`) no longer ship their own
  copies; they provide a connection and register it. App code imports
  `package:vania/database.dart` everywhere and names a driver in exactly one
  place — `main.dart`.

  ```dart
  import 'package:vania_mysql/vania_mysql.dart'; // only here

  void main() async {
    registerMySqlDriver();
    await Application.initialize(config: config);
  }
  ```

  Old `import 'package:vania_mysql/vania_mysql.dart' show Model, DB;` still
  resolves — each driver re-exports `package:vania/database.dart`.

- **Authentication moved to `vania_auth`.** The in-core auth surface
  (`lib/authentication.dart`, `Authenticate`, `HasApiTokens`,
  `RedirectIfAuthenticated`, and the legacy `Auth` singleton) is gone. Add
  `vania_auth` and import from there. `Gate`, `can()`, and `cannot()` stay in
  core, and `vania_auth` re-exports the same registry.

- **`Request.user` is resolved by an extension.** Core no longer knows what a
  user is; it calls a resolver installed with `setRequestUserResolver(...)`.
  `vania_auth`'s service provider installs one, so `req.user` keeps working the
  moment you register it. Without an auth package, `req.user` is `null`.

- **One `PersonalAccessTokenStore`.** The two competing definitions were
  merged into `lib/src/contract/http/personal_access_token_store.dart`
  (8 methods, `create` now requires `expiresIn`). Custom stores must implement
  `revoke`, `isRevoked`, `revokeAll`, `revokeAllByName`, and `find`.

- **Migrations and seeders throw instead of exiting.** `MigrationRunner`,
  `MigrationConnection`, and `SeederRunner` raise `DatabaseException` rather
  than calling `exit()`. Libraries throw; only the CLI decides an exit code.

- **Migrations are refused on staging and production.** `APP_ENV` now names a
  deployment mode — `local`, `staging`, or `production`. `vania migrate`,
  `migrate:fresh`, and `migrate:seed` stop with an error on the two protected
  modes unless you pass `--force`. An unset or unrecognised `APP_ENV` is read
  as `production`, so a misconfigured deployment fails safe.

- **`Migration.execute()` no longer rewrites your SQL.** It sends the string
  verbatim; the grammar translation is now opt-in via
  `Migration.executeAdapted()`. The old behaviour collapsed whitespace and
  stripped `COMMENT '…'`, which corrupted string literals in `INSERT`s.

- **`DatabaseAdapterInterface` grew.** Custom adapters must now provide
  `migrationsTable`, `renderTableOptions(...)`, and the blueprint renderers
  (`renderCreateTable`, `renderDropTable`, `renderAlterAddColumns`,
  `renderDropColumn`, `renderRenameColumn`, `renderRenameTable`,
  `renderAddIndex`, `renderDropIndex`).

- **`mailer` upgraded to 7.x.** `package:vania/mail.dart` now re-exports
  `Address` and the `Attachment` types from mailer's public library instead of
  its internals, which moved in mailer 7. The exported names are unchanged.

### Added

- **Blueprint-based migrations.** `Schema` collects structured column and table
  data, and each adapter renders native statements from it — no more
  regex-rewriting MySQL SQL into PostgreSQL. New operations:
  `dropColumn`, `renameColumn`, `renameTable`, `addIndex`, `dropIndex`. New
  column types: `uuid()`, `ipAddress()`, `macAddress()`, and a real
  `boolean()`.
- **MongoDB migrations.** `MongoAdapter` renders collection commands, so the
  same migration file runs on MySQL, PostgreSQL, SQLite, and MongoDB.
- **`AppEnvironment`.** `AppEnvironment.current()` reads `APP_ENV` and
  resolves the three deployment modes (with `dev`/`prod`/`stage` accepted as
  aliases). Exported from `package:vania/foundation.dart`.
- **`WebSocketUpgradeDispatcher`.** Every WebSocket upgrade the HTTP server
  receives goes through a dispatcher that extensions can override from their
  service provider, so `vania_websocket` and `vania_graphql` subscriptions run
  on the app's single port. Exported from `package:vania/websocket.dart`.
- **Shared connection registry.** `DatabaseConnectionFactory` and
  `ConnectionManager` live in core, so several drivers can be registered in one
  process and named connections resolve consistently.

### Changed

- Query-builder hot paths were rewritten around `StringBuffer`, a per-type
  table-name cache, a bindings fast path that skips the map copy when there is
  no CTE, and an interpolation-free `getTable`. These are locked in by
  `test/unit/database_perf_test.dart`.
- `Localization.init()` is awaited during `Application.initialize`, before the
  server accepts connections.
- MySQL renders `DROP TABLE` as three statements (disable FK checks, drop,
  restore) instead of one joined string.
- PostgreSQL emits `COMMENT ON COLUMN` on both the create and alter paths.
  Column collations are still dropped on PostgreSQL — migrations carry MySQL
  names like `utf8mb4_unicode_ci` that PostgreSQL rejects.
- SQLite and MySQL now throw `UnsupportedError` for alter operations they
  cannot express (SQLite: primary keys, unique constraints, foreign keys;
  MySQL: `beforeColumn`) instead of silently discarding them.

### Fixed

- Migration history was never recorded on MongoDB: the runner hardcoded a
  `migrations` table while `MongoAdapter` uses `_migrations`. Both now read
  `adapter.migrationsTable`.
- `Migration` resolved its adapter at construction time, so a migration
  instantiated before `MigrationConnection().setup()` silently no-opped every
  schema call. The adapter is now a getter.
- `TableDefinition` memoises its execution future — `then`, `catchError`,
  `whenComplete`, `timeout`, and `asStream` each used to re-run the whole
  migration.
- A duplicate migration class name now fails fast instead of quietly
  overwriting the earlier registration.
- Rolling back a migration whose class is no longer registered is refused,
  rather than deleting the history row and leaving the schema behind.
- The SQLite grammar's enum conversion handles every enum column, not just the
  first one.

### Upgrading from 1.x

1. Add a driver package and call its `register…Driver()` at the top of `main`.
2. Replace database imports with `import 'package:vania/database.dart';`.
3. Add `vania_auth` if you use authentication, and import `Authenticate` /
   `Auth` from it.
4. Set `APP_ENV` explicitly in every deployment, and add `--force` to the
   migration commands in your deploy scripts.
5. If you wrote a custom migration adapter or token store, implement the new
   contract members listed above.

## 1.2.0

### BREAKING

- **Encryption**: `VaniaEncryption` now uses a per-message random nonce (was
  hard-coded zeros). Session files encrypted with 1.1.x cannot be decrypted
  by 1.2.0 — sessions rotate on upgrade.
- **Request**: `input(key)` no longer silently coerces numeric-looking
  strings to `int`. Values like `"007"`, ZIP codes, or leading-zero IDs are
  returned as strings. Callers that need an int should use `integer(key)`.
- **View engine**: `TemplateEngine.sessionErrors`/`formData`/`sessions` now
  live in the current request `Zone` (via `TemplateEngine.runInRequestZone`),
  not on the singleton. Code that mutated them directly outside a request
  zone still works via a fallback bucket, but concurrent HTML requests no
  longer share state.
- **RouteHistory**: `Response.back()` now reads per-request state from the
  request zone rather than a global. Tabs and concurrent requests get their
  own history.
- **Localization**: `Localization.init()` returns `Future<void>` and is
  awaited inside `Application.initialize` before the server accepts
  connections. Extensions that called `init()` themselves should switch to
  `await`.
- **Application**: `APP_KEY` shorter than 32 characters now throws at
  startup.

### Security

- Fix(random): `randomString`/`randomInt` now use `Random.secure()` for
  session IDs and CSRF tokens (was a Mersenne Twister — predictable).
- Fix(encryption): AES-GCM nonce is now a fresh 12 random bytes per
  encryption. Fixed-nonce reuse was a textbook GCM misuse that leaked
  plaintext XORs across sessions.
- Fix(csrf): the middleware now runs its cookie + session-token checks
  BEFORE parsing the body, closing a DoS window where an attacker could
  force 10 MiB body parses with no valid token.
- Fix(body): body size cap is now enforced as bytes arrive on the stream,
  not only from the `Content-Length` header (which a client can lie about
  or omit).
- Fix(cookies): a malformed `Cookie` header no longer crashes the request
  handler; values that legitimately contain `=` (e.g. base64 padding) are
  preserved intact.

### Concurrency

- Fix(view engine): `sessionErrors`/`formData`/`sessions` are now per-request
  zone-locals; two concurrent HTML renders can no longer see each other's
  validation errors or old input.
- Fix(session): `SessionFileStore` now caches decrypted sessions in memory
  (LRU, `SESSION_CACHE_SIZE` env, default 5000). Cache invalidates on
  `deleteSession` and on file overwrite.
- Fix(route history): per-request zone-local storage; opening two tabs no
  longer confuses `Response.back()`.

### Performance

- Perf(router): dynamic routes are indexed per HTTP method; a GET request
  no longer scans POST dynamics. Static routes are indexed by normalized
  path for O(1) exact matches.
- Perf(router): domain-placeholder regex is pre-compiled once at boot.
- Perf(request): `Request.all()` builds the merged view once inside
  `extractBody()` and returns an unmodifiable snapshot; repeated calls are
  free.
- Perf(view engine): processor pipeline is now `static final` — 16 fewer
  allocations per HTML render.
- Perf(templates): `FileTemplateReader` caches parsed templates in
  production (`APP_DEBUG=false`). Debug mode re-reads for hot reload.
- Perf(throttle): cleanup runs amortized (every N requests or when the
  tracker grows past a threshold), not on every call.
- Perf(static files): served via `openRead()` streaming with proper
  `Content-Length`. Large files no longer allocate RAM proportional to
  file size.

### Reliability

- Fix(controller): uncaught controller errors log a stack trace via
  `Logger.log` — production debugging is no longer blind.
- Fix(request_file): `RequestFile.move()` reads via the cached `bytes`
  getter so `store()` + `move()` (or vice-versa) both succeed regardless
  of call order.
- Fix(response): `Response.makeResponse` now returns `Future<void>`;
  callers await the flush.
- Fix(localization): unknown locale no longer throws `NoSuchMethodError`;
  falls back to configured default, then to the key itself.

### Internal

- Refactor(request): `extractBody()` is idempotent; safe to call from
  middleware that wants body data early.
- Refactor(request_handler): body extraction now runs AFTER pre-middleware,
  so CSRF and other guards fail fast without paying for parse.

## 1.1.1

- Fix(db): switch from mysql_dart to mysql_client to fix UTF-8 encoding issues
- Chore update dependencies

## 1.1.0

- Add(FormValidation): add support for request validation using FormValidation
- Add(RequestHelper): introduce helper methods for accessing query strings, IP, and request data
- Add(Database): add database health check for non-pooled connections
- Add(Validation): implement builder pattern for defining validation rules (e.g. `field('name').required().string()`)
- Update(Pagination): use `getParam()` for retrieving `page` parameter in pagination
- Fix(RequestFile): handle `List<int>` stream in RequestFile.store
- Improve(Exception): enhance exception handling and error messages

## 1.0.2+2

- Fix(querybuilder): fixed `postgres` params name

## 1.0.2+1

- Fix(querybuilder): remove unnecessary `update_` prefix from update bindings

## 1.0.2

- Fix(Cache): fixed cache issue
- Fix(Request): fix `hasFile()` and `has()` method behavior
- Add(Request): add `asList()` method to get the data as a List
- Add(CSRF): add `CSRF_PROTECTION_ENABLED` config to toggle CSRF protection

## 1.0.1

- Refactor(ORM): fix eager-loading for polymorphic relations (`MorphTo`, `MorphToMany`, `MorphedByMany`) 
- Refactor(ORM): enhance eager-loading for core relations (`hasOne`, `hasMany`, `belongsTo`, `belongsToMany`)
- Fix(Database): decode byte arrays to `UTF-8` strings in query results

## 1.0.0

- Release stable version 1.0.0  
- Refactor and improve `QueryBuilder`: remove Eloquent package and implement core version  
- Implement full ORM functionality in core  
- Optimize routing system  
- Enhance request validation  
- Remove extraneous code and optimize core performance  

## 0.8.2

- Fix (Session): session file locking issue on Linux.  
- Fix (Static File): Automatically load `index.html` if the `/` route is not defined in web routes.  

## 0.8.1

- Fix(Request Validation): Custom validation rule Future
- fix(upload): prevent "Exhausted heap space" error on large file uploads

## 0.8.0

- Fix session bug
- Add `RedirectIfAuthenticated` Middleware
- Add(Response): Back with input
- Add(Request Validation): `RegExp` rule [#167](https://github.com/vania-dart/framework/issues/167)
- Add(Request Validation): Custom Validation Rule
- Add lockFile method for atomic session file handling
- Remove Isolate from code
- Refactor HttpRequest handler method to class-based structure

## 0.7.4+1

- chore: Upgraded project dependencies

## 0.7.4

- Add Route name
- Add(Template engine): Route `{@ route('home') @}` , `{@ route('home', {"id":1}) @}`
- Add(Template engine): assets `{@ asset('css/style.css') @}`
- Fix `csrf` url excluded

## 0.7.3

- Fix Authentication bug
- Refactor vania hash
- Fix incoming requests bug
- Fix csrf and session issue
- Fix Authentication issue
- Add(Template engine): `comment` tag to the template engine `{@# Comments here #@}`
- Add(Template engine): translate tag to the template engine `{@ trans('welcome', {"name": "Vania"}) @}`

## 0.7.2

- Add(Template engine): error handler `hasError('email')` , `{@ error('email') @}`
- Add(Template engine): session message handler `hasSession('email')` , `{@ session('success') @}`
- Add(Template engine): Cross-Site Request Forgery (`CSRF`) `{@ CSRF @}` , `{@ csrf_token() @}`
- Add `back()` to the response
- Refactor exception handling
- Refactor and sanitize route
- Add Basic Auth with session to the `Authenticate`
- chore: Upgraded project dependencies

## 0.7.1

- Add delete Session to the helper
- Add `async-await` for all Session methods

## 0.7.0

- Feat(Session Management): Session handling capabilities to manage user sessions effectively.
- Feat(Template engine): Support for rendering HTML templates using a template engine. To handle dynamic HTML rendering with support for control structures.
- chore: Upgraded project dependencies

## 0.6.2

- Add redirect method [#144](https://github.com/vania-dart/framework/issues/144)
- Add custom 404 error handling via HTML file [#145](https://github.com/vania-dart/framework/issues/145)

## 0.6.1

- Fix get language path

## 0.6.0

- Refactor incoming route log
- Remove unnecessary library name
- Add Multi-language support [#141](https://github.com/vania-dart/framework/issues/141) [Localization](https://vdart.dev/docs/the-basics/localization)

## 0.5.1

- Add support for unique constraints in migrations. Thanks to [WellingtonNico](https://github.com/WellingtonNico) for the contribution.
- Refactor configuration initialization by moving database setup before service provider registration, ensuring a more reliable startup sequence.
- Fix Resolved an issue with WebSocket middleware that caused unexpected behavior. See [#132](https://github.com/vania-dart/framework/issues/132) for details.
- Chore Upgraded dependencies to their latest versions.

## 0.5.0

- Feat: Gate feature for defining user permissions
- Add WebSocket connect, disconnect, and error handling on the server side (#126)
- Add user getter method to Request class

## 0.4.3

- Fix nested JSON [#128](https://github.com/vania-dart/framework/issues/128)
- Add JSON to the request `request.json()`

## 0.4.2

- Fix id auto-increment for PostgreSQL compatibility [#127](https://github.com/vania-dart/framework/issues/118)

## 0.4.1

- Refactor validation rule customErrorMessage to message
- Fix JSON response for API
- Fix PostgreSQL sslmode [#118](https://github.com/vania-dart/framework/issues/118)
- Add enable support for list item submission `form/data` request
- chore: upgrade dependencies

## 0.4.0

- Feat: a new field validation mechanism by [alirezat66](https://github.com/alirezat66) - [PR 99](https://github.com/vania-dart/framework/pull/99)
- Fix nested route group [#98](https://github.com/vania-dart/framework/issues/98)
- Fix middleware issue

## 0.3.5+1

- Fix send message to room

## 0.3.5

- Fix WebSocket session id
- Add get room members
- Add is active session
- Add get active room
- Add get active sessions

## 0.3.4

- Fix route camel-case issue
- Add get cookie from the request

## 0.3.3+1

- Fix encoding char-set for form input handling

## 0.3.3

- Fix group route issue
- Fix uuid issue (#88)
- Add `Server-Sent Events (SSE)` response (#89) Thank you [Dartly](https://github.com/Dartly)

## 0.3.2

- Refactor Response class
- Add jsonWithHeader response
- Add QueryException to model class
- Add Databse helper
- Add Create and InsertMany to the ORM
- Add DB Transaction
- Add Cookies,Integer,asDouble to request class
- Fix request body int fields
- Fix PostgreSQL typo
- Fix drop table issue when table has foreign key

## 0.3.1

- Fix Refresh token bug([#83](https://github.com/vania-dart/framework/issues/83))
- Fix WebSocket connect event

## 0.3.0

- Add Parameter validation conditions for the router([#79](https://github.com/vania-dart/framework/issues/79))
- Add Resource and Any route ([#80](https://github.com/vania-dart/framework/issues/80))
- Refactor Router, Route Handler
- Refactor Controller handler for increasing RPS and decreasing latency
- Refactor Request handler for increase RPS
- Fix Null params ([#81](https://github.com/vania-dart/framework/issues/81))

## 0.2.7

- Optimize PRS
- Refactor Controller handler
- Refactor Request handler
- Refactor Request class
- Add none to response type and await for res close
- Refactor route handler
- Export Database client
- Add URL assets to helper

## 0.2.6

- Refactor Local storage class
- Refactor Cache class
- Refactor Storage class
- Refactor Response class
- Add AWS S3 storage driver
- Add Storage env config

```env
    STORAGE=s3
    STORAGE_S3_BUCKET=''
    STORAGE_S3_SECRET_KEY=''
    STORAGE_S3_ACCESS_KEY=''
    STORAGE_S3_REGION=''
```

## 0.2.5

- Fix Authentication middleware issue
- Fix static file url encoding
- Add Domian to router
- Add JWT env config

```env
    JWT_SECRET_KEY
    JWT_AUDIENCE
    JWT_ID
    JWT_ISSUER
    JWT_SUBJECT
 ```

## 0.2.4

- Fix Route bug
- Add WebSocket middleware
- Refactor Auth middleware

## 0.2.3

- Fix Database connection issue with Isolate

## 0.2.2

- Fix Websocket Join and Left room issue([#63](https://github.com/vania-dart/framework/issues/63))
- Refactor Migration and model
- Add DatabseClient class

## 0.2.1

- Fix Postgresql bug

## 0.2.0

- Add Redis (base code from dedis dart package)
- Add Redis Cache Driver

## 0.1.9

- Fix Isolate bug

## 0.1.8

- Fix public and storage file path
- Refactor Mailable Config to env
- Refactor Migration class, created migration timestamp Add by [S.M. SHAHi](https://github.com/shahi5472)
- Refactor Local cache class name to File cache

## 0.1.7+5

- Add pool and poolsize to DatabaseConfig

## 0.1.7+4

- Fix pgsql bug
- Add alter column to the migration

## 0.1.7+3

- Refactor HttpException to HttpResponseException
- Add abort method to the helper file

## 0.1.7+2

- Fix route group bug

## 0.1.7+1

- Fix env issue

## 0.1.7

- Add deleteTokens and deleteCurrentToken Auth class
- Refactor group routing to use a callback function instead of a list
- Refactor websocket data to payload
- Add Middleware Handler
- Fix Webscoket Route bug
- Update Dependencies
- Add secure bind

## 0.1.6+1

- Fix Storage issues

## 0.1.6

- Fix Websocket bugs
- Refactor Storage Converted Instance Methods to Static Methods
- Refactor Cache Converted Instance Methods to Static Methods

## 0.1.5+1

- Fix env issues

## 0.1.5

- Add Logger
- Add env file

## 0.1.4

- Add Throttle middleware
- Add move for upload file in custom folder
- Add paginate and simplePagination in Eloquent

## 0.1.3

- Add mail

## 0.1.2

- Add multi-isolate server

## 0.1.1+4

- Fix Validation issue on non-required fields

## 0.1.1+3

- Add Singleton base route preFix   to static
- Readme file

## 0.1.1+2

- Fix bug: Cors file and class name

## 0.1.1+1

- Fix bug: http method options and cors error

- ## 0.1.1

- Add Hash class

## 0.1.0

- Initial beta release
- Fix a bug related to WebSocket data events
- Fix authentication check functionality
- Add `isAuthorized` feature
- Add `query_builder` from Eloquent package for enhanced functionality

## 0.0.4

- Fix bug: Authentication refresh token

## 0.0.3+1

- Fix bug: migration columns length
- Add sslmode to the MySqldriver

## 0.0.3

- Fix Bug: Resolved issue with table creation in PostgreSQL

## 0.0.2+1

- Add bigIncrements and  softDeletes columns

## 0.0.2

- Add column index to vania file
- Code formatted

## 0.0.1

- Initial version.
