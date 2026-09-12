---
sidebar_position: 2
---

# Query Builder

Vania's query builder provides a fluent interface for constructing and executing database queries. It works with MySQL, PostgreSQL, and MongoDB through the same API.

## Retrieving Results

```dart
import 'package:vania/database.dart';

// All rows
var users = await DB.table('users').get();

// First row
var user = await DB.table('users').where('id', '=', 1).first();

// First row or throw
var user = await DB.table('users').where('id', '=', 1).firstOrFail();

// Find by primary key
var user = await DB.table('users').find(1);
var user = await DB.table('users').findOrFail(1);

// First match by column
var user = await DB.table('users').firstWhere('email', '=', 'alice@example.com');

// Single column value
var email = await DB.table('users').where('id', '=', 1).value('email');

// Column as list
var emails = await DB.table('users').pluck('email');

// Check existence
bool exists = await DB.table('users').where('email', '=', 'alice@example.com').exists();
bool missing = await DB.table('users').where('email', '=', 'nobody@example.com').doesntExist();
```

## Select Columns

```dart
var users = await DB.table('users').select(['id', 'name', 'email']).get();

// Add columns
var users = await DB.table('users')
    .select(['id', 'name'])
    .addSelect(['email'])
    .get();

// Raw select
var users = await DB.table('users')
    .selectRaw('count(*) as total, status')
    .groupBy('status')
    .get();

// Subquery select
var users = await DB.table('users')
    .selectSub(
      DB.table('posts').selectRaw('count(*)').whereColumn('posts.user_id', '=', 'users.id'),
      'post_count',
    )
    .get();
```

## Where Clauses

### Basic Where

```dart
var users = await DB.table('users')
    .where('status', '=', 'active')
    .where('age', '>=', 18)
    .get();

// Shorthand for equality
var user = await DB.table('users').whereEqualTo('email', 'alice@example.com').first();
```

### Or Where

```dart
var users = await DB.table('users')
    .where('role', '=', 'admin')
    .orWhere('role', '=', 'editor')
    .get();
```

### Where In / Not In

```dart
var users = await DB.table('users')
    .whereIn('role', ['admin', 'editor'])
    .get();

var users = await DB.table('users')
    .whereNotIn('status', ['banned', 'suspended'])
    .get();
```

### Where Null / Not Null

```dart
var unverified = await DB.table('users').whereNull('email_verified_at').get();
var verified = await DB.table('users').whereNotNull('email_verified_at').get();
```

### Where Between

```dart
var users = await DB.table('users').whereBetween('age', [18, 65]).get();
```

### Date / Time Where Clauses

```dart
var today = await DB.table('orders').whereDate('created_at', '=', '2026-07-11').get();
var july = await DB.table('orders').whereMonth('created_at', '=', 7).get();
var year = await DB.table('orders').whereYear('created_at', '=', 2026).get();
var morning = await DB.table('orders').whereHour('created_at', '<', 12).get();

// Convenience methods
var todayOrders = await DB.table('orders').whereToday('created_at').get();
var pastOrders = await DB.table('orders').wherePast('created_at').get();
var futureOrders = await DB.table('orders').whereFuture('created_at').get();
```

### Where Like

```dart
var users = await DB.table('users').whereLike('name', '%alice%').get();
var users = await DB.table('users').whereNotLike('name', '%test%').get();
```

### Where Column (comparing two columns)

```dart
var users = await DB.table('users')
    .whereColumn('updated_at', '>', 'created_at')
    .get();
```

### Where Exists (subquery)

```dart
var usersWithPosts = await DB.table('users')
    .whereExists(
      DB.table('posts').whereColumn('posts.user_id', '=', 'users.id'),
    )
    .get();
```

### JSON Where Clauses

```dart
var users = await DB.table('users')
    .whereJsonContains('preferences->theme', 'dark')
    .get();

var users = await DB.table('users')
    .whereJsonLength('tags', '>', 3)
    .get();
```

### Where Full Text

```dart
var posts = await DB.table('posts')
    .whereFullText(['title', 'body'], 'dart framework')
    .get();
```

### Raw Where

```dart
var users = await DB.table('users')
    .whereRaw('YEAR(created_at) = ?', [2026])
    .get();
```

### Relation-Aware Where

```dart
var usersWithPosts = await DB.table('users').whereHas('posts').get();
var usersWithoutPosts = await DB.table('users').whereDoesntHave('posts').get();
```

## Ordering

```dart
var users = await DB.table('users').orderBy('name', 'asc').get();
var users = await DB.table('users').orderByDesc('created_at').get();
var latest = await DB.table('users').latest('created_at').get();
var random = await DB.table('users').inRandomOrder().get();
```

## Grouping

```dart
var stats = await DB.table('orders')
    .select(['status'])
    .selectRaw('count(*) as total')
    .groupBy('status')
    .having('total', '>', 10)
    .get();
```

## Limit and Offset

```dart
var users = await DB.table('users').limit(10).offset(20).get();

// Aliases
var users = await DB.table('users').take(10).skip(20).get();
```

## Joins

```dart
var results = await DB.table('users')
    .join('posts', 'users.id', '=', 'posts.user_id')
    .select(['users.name', 'posts.title'])
    .get();

// Left join
var results = await DB.table('users')
    .leftJoin('posts', 'users.id', '=', 'posts.user_id')
    .get();

// Right join
var results = await DB.table('users')
    .rightJoin('posts', 'users.id', '=', 'posts.user_id')
    .get();

// Cross join
var results = await DB.table('sizes').crossJoin('colors').get();

// Subquery join
var results = await DB.table('users')
    .joinSub(
      DB.table('posts').selectRaw('user_id, count(*) as post_count').groupBy('user_id'),
      'post_stats',
      'users.id', '=', 'post_stats.user_id',
    )
    .get();
```

## Unions

```dart
var admins = DB.table('users').where('role', '=', 'admin');
var editors = DB.table('users').where('role', '=', 'editor');
var results = await admins.union(editors).get();
var results = await admins.unionAll(editors).get();
```

## Inserts

```dart
await DB.table('users').insert({
  'name': 'Alice',
  'email': 'alice@example.com',
});

// Insert and get the auto-increment ID
var id = await DB.table('users').insertGetId({
  'name': 'Bob',
  'email': 'bob@example.com',
});

// Insert multiple rows
await DB.table('users').insertMany([
  {'name': 'Alice', 'email': 'alice@example.com'},
  {'name': 'Bob', 'email': 'bob@example.com'},
]);

// Insert or ignore on conflict
await DB.table('users').insertOrIgnore({'email': 'alice@example.com', 'name': 'Alice'});

// Upsert (insert or update)
await DB.table('users').upsert(
  {'email': 'alice@example.com', 'name': 'Alice Updated'},
  ['email'],          // unique columns
  ['name'],           // columns to update on conflict
);
```

## Updates

```dart
await DB.table('users').where('id', '=', 1).update({'name': 'Alice Smith'});

// Update or insert
await DB.table('users').updateOrInsert(
  {'email': 'alice@example.com'},  // search criteria
  {'name': 'Alice', 'role': 'admin'},  // values to set
);

// Increment / Decrement
await DB.table('posts').where('id', '=', 1).increment('views');
await DB.table('posts').where('id', '=', 1).increment('views', 5);
await DB.table('accounts').where('id', '=', 1).decrement('balance', 100);

// Increment multiple columns
await DB.table('posts').where('id', '=', 1).incrementEach({
  'views': 1,
  'shares': 2,
});
```

## Deletes

```dart
await DB.table('users').where('id', '=', 1).delete();

// Truncate table
await DB.table('logs').truncate();
```

## Aggregates

```dart
int total = await DB.table('users').count();
double avgAge = await DB.table('users').avg('age');
num sum = await DB.table('orders').sum('total');
num maxPrice = await DB.table('products').max('price');
num minPrice = await DB.table('products').min('price');
```

## Pagination

```dart
var result = await DB.table('users').paginate(perPage: 15, page: 1);
// Returns: {data: [...], current_page: 1, per_page: 15, total: 150, last_page: 10, ...}

var result = await DB.table('users').simplePaginate(perPage: 15);
// Lighter version without total count
```

## Chunking

Process large result sets in chunks to avoid memory issues:

```dart
await DB.table('users').chunk(100, (users) {
  for (var user in users) {
    // process user
  }
});

await DB.table('users').chunkById(100, (users) {
  for (var user in users) {
    // process user
  }
});
```

## Common Table Expressions (CTEs)

```dart
var result = await DB.table('employees')
    .withCte('managers', DB.table('employees').where('role', '=', 'manager'))
    .join('managers', 'employees.manager_id', '=', 'managers.id')
    .get();

// Recursive CTE
var tree = await DB.table('categories')
    .withRecursive(
      'category_tree',
      DB.table('categories').whereNull('parent_id'),       // base case
      DB.table('categories').join('category_tree', 'categories.parent_id', '=', 'category_tree.id'),  // recursive
    )
    .get();
```

## Window Functions

```dart
var result = await DB.table('employees')
    .select(['name', 'department', 'salary'])
    .rowNumber(orderBy: 'salary', direction: 'desc', partitionBy: 'department', alias: 'rank')
    .get();

// Other window functions: rank, denseRank, lag, lead, ntile,
// firstValue, lastValue, percentRank, cumeDist,
// windowSum, windowAvg, windowCount, windowMax, windowMin
```

## Bulk Operations

```dart
// Bulk insert with conflict handling
await DB.table('users').bulkInsert(
  [{'name': 'Alice'}, {'name': 'Bob'}],
  conflictAction: ConflictAction.ignore,
  batchSize: 500,
);

// Bulk update
await DB.table('products').bulkUpdate(
  [{'id': 1, 'price': 29.99}, {'id': 2, 'price': 39.99}],
  matchColumn: 'id',
  updateColumns: ['price'],
);

// Bulk delete
await DB.table('logs').bulkDelete(column: 'id', values: [1, 2, 3]);
```

## Raw Expressions

```dart
var users = await DB.table('users')
    .select([DB.raw('CONCAT(first_name, " ", last_name) as full_name')])
    .get();
```

## Debugging

```dart
var query = DB.table('users').where('status', '=', 'active');

// Get the SQL string
String sql = query.toSql();

// Get the SQL with bindings replaced
String rawSql = query.toRawSql();

// Get binding values
Map<String, dynamic> bindings = query.getBindings();
```
