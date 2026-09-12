---
sidebar_position: 4
---

# Relationships

Vania supports the full range of model relationships: one-to-one, one-to-many, many-to-many, and polymorphic variants. Relationships are defined in the model's `registerRelations()` method.

## Defining Relationships

Override `registerRelations()` in your model to declare how it connects to other models:

```dart
class User extends Model {
  @override
  List<String> get fillable => ['name', 'email'];

  @override
  void registerRelations() {
    hasOne('profile', Profile(), foreignKey: 'user_id');
    hasMany('posts', Post(), foreignKey: 'user_id');
    belongsToMany('roles', Role(), pivotTable: 'role_user');
  }
}
```

## One-to-One: hasOne

A user has one profile:

```dart
class User extends Model {
  @override
  void registerRelations() {
    hasOne('profile', Profile(), foreignKey: 'user_id', localKey: 'id');
  }
}
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `name` | — | Relation name (used with `include()`) |
| `related` | — | Instance of the related model |
| `foreignKey` | `{RelatedType}_id` | Foreign key on the related table |
| `localKey` | `id` | Local key on this table |

## One-to-Many: hasMany

A user has many posts:

```dart
class User extends Model {
  @override
  void registerRelations() {
    hasMany('posts', Post(), foreignKey: 'user_id');
  }
}
```

## Inverse: belongsTo

A post belongs to a user:

```dart
class Post extends Model {
  @override
  void registerRelations() {
    belongsTo('user', User(), foreignKey: 'user_id', localKey: 'id');
  }
}
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `foreignKey` | `{RelatedType}_id` | Foreign key on this table |
| `localKey` | `id` | Primary key on the parent table |

## Many-to-Many: belongsToMany

Users and roles connected through a pivot table:

```dart
class User extends Model {
  @override
  void registerRelations() {
    belongsToMany(
      'roles',
      Role(),
      pivotTable: 'role_user',
      parentPivotKey: 'user_id',
      relatedPivotKey: 'role_id',
    );
  }
}

class Role extends Model {
  @override
  void registerRelations() {
    belongsToMany(
      'users',
      User(),
      pivotTable: 'role_user',
      parentPivotKey: 'role_id',
      relatedPivotKey: 'user_id',
    );
  }
}
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `pivotTable` | Derived from both model names | The intermediate table |
| `parentPivotKey` | — | This model's key in the pivot table |
| `relatedPivotKey` | — | Related model's key in the pivot table |
| `parentLocalKey` | `id` | This model's primary key |
| `relatedLocalKey` | `id` | Related model's primary key |

## Polymorphic: morphOne / morphMany

When a model can belong to more than one type of parent. For example, both posts and videos can have comments:

```dart
class Comment extends Model {
  @override
  void registerRelations() {
    morphTo('commentable', Post(), morphKey: 'commentable_id', morphType: 'commentable_type');
  }
}

class Post extends Model {
  @override
  void registerRelations() {
    morphMany('comments', Comment(), morphKey: 'commentable_id', morphType: 'commentable_type');
  }
}

class Video extends Model {
  @override
  void registerRelations() {
    morphMany('comments', Comment(), morphKey: 'commentable_id', morphType: 'commentable_type');
  }
}
```

### morphOne

Like `morphMany` but returns a single related model:

```dart
class User extends Model {
  @override
  void registerRelations() {
    morphOne('avatar', Image(), morphKey: 'imageable_id', morphType: 'imageable_type');
  }
}
```

### morphTo

The inverse of `morphOne` and `morphMany`:

```dart
class Image extends Model {
  @override
  void registerRelations() {
    morphTo('imageable', User(), morphKey: 'imageable_id', morphType: 'imageable_type');
  }
}
```

## Polymorphic Many-to-Many: morphToMany / morphedByMany

Tags that can be applied to posts, videos, and other models:

```dart
class Post extends Model {
  @override
  void registerRelations() {
    morphToMany(
      'tags',
      Tag(),
      morphKey: 'taggable_id',
      morphType: 'taggable_type',
      pivotTable: 'taggables',
      relatedMorphKey: 'tag_id',
    );
  }
}

class Tag extends Model {
  @override
  void registerRelations() {
    morphedByMany(
      'posts',
      Post(),
      morphKey: 'taggable_id',
      morphType: 'taggable_type',
      pivotTable: 'taggables',
      relatedMorphKey: 'tag_id',
    );
  }
}
```

## Eager Loading

Avoid the N+1 query problem by eager loading relationships:

```dart
// Load a single relation
var users = await User().query.include('posts').get();

// Load multiple relations
var users = await User().query
    .include('posts')
    .include('profile')
    .include('roles')
    .get();

// Nested eager loading
var users = await User().query.include('posts.comments').get();

// Constrain eager loaded relations
var users = await User().query
    .include('posts', (query) => query
        .where('published', '=', true)
        .orderBy('created_at', 'desc')
        .limit(5))
    .get();

// Select specific columns
var users = await User().query.include('posts:title,created_at').get();
```

## Querying with Relations

Use `whereHas` and `whereDoesntHave` to filter based on related records:

```dart
// Users who have at least one post
var authors = await User().query.whereHas('posts').get();

// Users with no posts
var readers = await User().query.whereDoesntHave('posts').get();
```

## Relation Summary

| Relationship | Method | Example |
|-------------|--------|---------|
| One-to-One | `hasOne` | User → Profile |
| One-to-Many | `hasMany` | User → Posts |
| Many-to-One | `belongsTo` | Post → User |
| Many-to-Many | `belongsToMany` | User ↔ Roles |
| Polymorphic One | `morphOne` | User → Image |
| Polymorphic Many | `morphMany` | Post → Comments |
| Polymorphic Inverse | `morphTo` | Comment → Commentable |
| Polymorphic M2M | `morphToMany` | Post → Tags |
| Polymorphic M2M Inverse | `morphedByMany` | Tag → Posts |
