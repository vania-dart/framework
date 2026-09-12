---
sidebar_position: 3
---

# Models

Models are the ORM layer on top of the query builder. Each model maps to a database table and provides methods for creating, reading, updating, and deleting records with relation support, mass assignment protection, timestamps, and soft deletes.

## Defining a Model

```dart
import 'package:vania/database.dart';

class User extends Model {
  @override
  List<String> get fillable => ['name', 'email', 'password'];

  @override
  List<String> get hidden => ['password'];

  @override
  bool get timestamps => true;
}

class Post extends Model {
  @override
  List<String> get fillable => ['title', 'body', 'user_id'];

  @override
  bool get softDeletes => true;
}
```

## Table Name Convention

By default, the table name is derived from the class name: it is converted to snake_case and pluralized.

| Class Name | Table Name |
|-----------|------------|
| `User` | `users` |
| `BlogPost` | `blog_posts` |
| `Category` | `categories` |
| `PersonAddress` | `person_addresses` |

To set a custom table name:

```dart
class User extends Model {
  User() {
    super.table('app_users');
  }
}
```

You can also add a table prefix:

```dart
class User extends Model {
  @override
  String get tablePrefix => 'app_';
  // Table: app_users
}
```

## Primary Key

The default primary key is `id` with auto-incrementing integers. To customize:

```dart
class User extends Model {
  @override
  String get primaryKey => 'user_id';

  @override
  String get keyType => 'string';  // for UUID primary keys

  @override
  bool get incrementing => false;  // disable auto-increment
}
```

## Retrieving Records

All queries go through the `query` getter, which returns a fresh query scoped to the model's table:

```dart
// All records
var users = await User().query.get();

// Find by primary key
var user = await User().query.find(1);
var user = await User().query.findOrFail(1);

// Find by specific column
var user = await User().query.find('alice@example.com', byColumnName: 'email');

// Select specific columns
var users = await User().query.get(['id', 'name', 'email']);

// With conditions
var admins = await User().query
    .where('role', '=', 'admin')
    .where('active', '=', true)
    .get();

// First match
var admin = await User().query.where('role', '=', 'admin').first();
var admin = await User().query.firstWhere('role', '=', 'admin');
```

## Creating Records

```dart
var user = await User().query.create({
  'name': 'Alice',
  'email': 'alice@example.com',
  'password': Hash().make('secret'),
});
// Returns the full record with id and timestamps populated
```

`create()` inserts the record, adds `created_at` and `updated_at` timestamps automatically, and returns the newly created row fetched by its ID.

## Updating Records

```dart
await User().query.where('id', '=', 1).update({
  'name': 'Alice Smith',
});
// updated_at is set automatically
```

## Deleting Records

```dart
await User().query.where('id', '=', 1).delete();
```

### Soft Deletes

When `softDeletes` is `true`, `delete()` sets the `deleted_at` column instead of removing the row. All queries automatically exclude soft-deleted records.

```dart
class Post extends Model {
  @override
  bool get softDeletes => true;

  @override
  String get deletedAt => 'deleted_at';  // column name (default)
}

// This sets deleted_at instead of removing the row
await Post().query.where('id', '=', 1).delete();

// Query soft-deleted records too
var allPosts = await Post().query.withSoftDeletes().get();
```

## Timestamps

When `timestamps` is `true` (the default), `create()` sets `created_at` and `updated_at`, and `update()` refreshes `updated_at`.

Customize column names:

```dart
class Post extends Model {
  @override
  String get createdAt => 'created_at';
  @override
  String get updatedAt => 'updated_at';
}
```

Disable timestamps:

```dart
class Log extends Model {
  @override
  bool get timestamps => false;
}
```

## Mass Assignment Protection

Control which fields can be set through `create()` and `update()`:

```dart
class User extends Model {
  // Only these columns can be mass-assigned
  @override
  List<String> get fillable => ['name', 'email', 'password'];
}
```

Or use `guarded` to block specific columns:

```dart
class User extends Model {
  @override
  List<String> get guarded => ['is_admin', 'role'];
}
```

If both `fillable` and `guarded` are empty, no columns can be mass-assigned — the framework throws an `InvalidArgumentException`.

## Hidden Fields

Fields in `hidden` are excluded from `get()`, `toJson()`, and other output methods:

```dart
class User extends Model {
  @override
  List<String> get hidden => ['password', 'remember_token'];
}
```

## Attributes

After fetching a record, access its data through `attributes`:

```dart
var user = await User().query.find(1);
String name = user?.getAttribute('name');
int? id = user?.getKey();
bool hasEmail = user?.hasAttribute('email') ?? false;
```

## Pagination

```dart
var result = await User().query.paginate(perPage: 15, page: 1);
// Returns: {data: [...], current_page: 1, per_page: 15, total: 150,
//           last_page: 10, is_first: true, is_last: false, has_more: true}

var result = await User().query.simplePaginate(perPage: 15);
```

## Aggregates

```dart
int count = await User().query.count();
double avg = await User().query.avg('age');
num total = await User().query.where('status', '=', 'active').sum('balance');
```

## Eager Loading Relations

Load related models efficiently with `include()`:

```dart
// Load one relation
var users = await User().query.include('posts').get();

// Load multiple relations
var users = await User().query.include('posts').include('profile').get();

// Nested relations (dot notation)
var users = await User().query.include('posts.comments').get();

// Select specific columns for the relation
var users = await User().query.include('posts:title,body').get();

// Constrain the relation query
var users = await User().query
    .include('posts', (query) => query.where('published', '=', true).orderBy('created_at', 'desc'))
    .get();
```

## Model Comparison

```dart
var user1 = await User().query.find(1);
var user2 = await User().query.find(1);
bool same = user1?.is_(user2) ?? false;  // true (same key + table)
```

## Serialization

```dart
var user = await User().query.find(1);
Map<String, dynamic> json = user?.toJson() ?? {};
// Hidden fields are excluded, loaded relations are included
```

## Generating Models via CLI

```bash
vania make:model post
```

Creates `lib/app/models/post.dart` with a `Post` class extending `Model`.
