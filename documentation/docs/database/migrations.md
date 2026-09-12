---
sidebar_position: 5
---

# Migrations

Migrations are version-controlled schema changes. Each migration is a class with an `up()` method that applies the change and a `down()` method that reverses it.

## Creating a Migration

```bash
vania make:migration create_posts_table
```

This generates a file in `lib/database/migrations/`. Inside `up()`, call `create()` with the table name and a callback that receives a `Schema`. You declare columns on that `schema` object:

```dart
import 'package:vania/database.dart';

class CreatePostsTable extends Migration {
  @override
  Future<void> up() async {
    await create('posts', (Schema schema) {
      schema.id();
      schema.string('title');
      schema.text('body');
      schema.bigInt('user_id');
      schema.boolean('published').defaultTo(false);
      schema.timeStamps();
      schema.softDeletes();
    }, true); // the trailing `true` means "if not exists"
  }

  @override
  Future<void> down() async {
    await drop('posts');
  }
}
```

The third argument to `create()` is `ifNotExists` (defaults to `false`). The CLI also registers the new migration in `migrate.dart` for you.

> The column methods are called on the `schema` argument — `schema.id()`, `schema.string(...)`, and so on. (Older releases exposed `createTableNotExists`/`dropIfExists` and bare `id()`/`string()` calls; those are deprecated — use `create(..., true)` and `drop()`.)

## Running Migrations

```bash
vania migrate
```

| Command | Description |
|---------|-------------|
| `vania migrate` | Run pending migrations |
| `vania migrate:fresh` | Drop all tables and re-run every migration |

The runner records which migrations have run (with batch numbers) in a `migrations` table, so `vania migrate` only applies new ones.

### Protected environments

`APP_ENV` names the deployment mode: `local`, `staging`, or `production`. On
`staging` and `production` the runner refuses to run — `vania migrate`,
`migrate:fresh`, `--refresh`, `--reset`, `--rollback` and `--install` all stop
with an error naming the environment, before touching the database:

```
Refusing to run "migrate": APP_ENV is production. This would change a
production database. Re-run with --force if that is what you want.
```

Pass `--force` when you really do mean to migrate that database:

```bash
vania migrate --force
```

Only `APP_ENV=local` runs unguarded. An unset or unrecognised `APP_ENV`
resolves to `production`, so a misconfigured deployment fails safe rather than
migrating silently.

## Column Types

Call these on the `schema` object inside the `create()` callback.

### Numeric

```dart
schema.id();                                  // auto-incrementing bigint primary key
schema.bigIncrements('id');
schema.integer('age');
schema.tinyInt('status');
schema.smallInt('priority');
schema.mediumInt('count');
schema.bigInt('population');
schema.float('latitude');
schema.double('price');
schema.decimal('amount', precision: 10, scale: 2);
schema.boolean('active');
schema.bit('flags');
```

### String

```dart
schema.string('name', length: 255);
schema.char('code', length: 2);
schema.tinyText('summary');
schema.text('description');
schema.mediumText('content');
schema.longText('full_text');
schema.uuid('identifier');
```

### Date and Time

```dart
schema.date('birthday');
schema.time('alarm_time');
schema.year('graduation_year');
schema.dateTime('published_at');
schema.timeStamp('verified_at');
schema.timeStamps();               // created_at and updated_at
schema.softDeletes();              // deleted_at
schema.softDeletes('removed_at');  // custom column name
```

### Binary, JSON, Enum, Spatial

```dart
schema.binary('data');
schema.varBinary('hash', length: 64);
schema.blob('image');
schema.json('metadata');
schema.enumType('status', ['draft', 'published', 'archived']);
schema.setType('permissions', ['read', 'write', 'execute']);
schema.point('location');
schema.geometry('shape');
```

## Column Modifiers

Chain modifiers on the column:

```dart
schema.string('email', length: 255).nullable().unique();
schema.integer('sort_order').defaultTo(0);
schema.dateTime('expires_at').nullable().index();
schema.string('sku').unique('idx_products_sku');
schema.text('bio').nullable().comment('User biography');
schema.string('name').collate('utf8mb4_unicode_ci');
```

| Modifier | Description |
|----------|-------------|
| `.nullable()` | Allow NULL |
| `.notNull()` | Disallow NULL (default) |
| `.defaultTo(value)` | Set a default |
| `.defaultToCurrent()` | Default to `CURRENT_TIMESTAMP` |
| `.unsigned()` | Unsigned numeric |
| `.unique([name])` | Add a unique constraint |
| `.index([name, type])` | Add an index |
| `.comment(String)` | Column comment |
| `.collate(String)` | Column collation |

## Foreign Keys and Indexes

```dart
await create('posts', (Schema schema) {
  schema.id();
  schema.bigInt('user_id');
  schema.string('title');
  schema.timeStamps();

  // Foreign key
  schema.foreign('user_id', 'users', 'id', onDelete: 'CASCADE');

  // Composite index / unique constraint
  schema.addCompositeIndex('idx_user_title', ['user_id', 'title']);
  schema.addCompositeUniqueConstraint('uq_user_slug', ['user_id', 'slug']);
}, true);
```

## Altering a Table

`alterColumn()` adds columns to an existing table. It takes the same `Schema` callback:

```dart
@override
Future<void> up() async {
  await alterColumn('users', (Schema schema) {
    schema.string('phone', length: 20).nullable();
    schema.boolean('verified').defaultTo(false);
  });
}
```

Position a new column with `beforeColumn:` or `afterColumn:`:

```dart
await alterColumn('users', (Schema schema) {
  schema.string('middle_name').nullable();
}, afterColumn: 'first_name');
```

## Dropping a Table

```dart
@override
Future<void> down() async {
  await drop('posts');
}
```

## Raw SQL

```dart
@override
Future<void> up() async {
  await execute('CREATE INDEX idx_posts_title ON posts (title(50))');
}
```

## Table Options

`create()` returns a `TableDefinition` you can chain engine/charset options onto before awaiting it:

```dart
await create('posts', (Schema schema) {
  schema.id();
  schema.string('title');
  schema.timeStamps();
}, true)
  .engine('InnoDB')
  .charset('utf8mb4')
  .collate('utf8mb4_unicode_ci')
  .comment('Blog posts');
```

## The Migration Registry

`migrate.dart` runs your migrations in order. The CLI keeps it up to date as you add migrations:

```dart
void main() async {
  final migrate = Migrate();
  await migrate.registry();
}

class Migrate {
  Future<void> registry() async {
    await MigrationConnection().setup();
    await CreateUsersTable().up();
    await CreatePostsTable().up();
    await MigrationConnection().closeConnection();
  }
}
```
