---
sidebar_position: 3
---

# Requests

The `Request` object wraps the incoming HTTP request and provides a clean API for accessing input data, query parameters, route parameters, headers, cookies, and uploaded files.

## Accessing the Request

Add `Request` as the first parameter of your controller method:

```dart
Future<Response> store(Request req) async {
  String title = req.input('title');
  return Response.json({'title': title});
}
```

## Input Data

### Merged Input

`all()` returns a merged view of body data, query parameters, and route parameters:

```dart
Map<String, dynamic> data = req.all();
```

### Individual Values

```dart
// Raw value — returns the value as-is, no type coercion
var name = req.input('name');
var name = req.input('name', 'default');

// Typed accessors
String title = req.string('title');
int age = req.integer('age');
double price = req.asDouble('price');
bool active = req.boolean('active');
DateTime date = req.date('published_at');
List items = req.asList('tags');
```

### Selective Access

```dart
// Only specific keys
Map<String, dynamic> filtered = req.only(['name', 'email']);

// Everything except specific keys
Map<String, dynamic> partial = req.except('password');
```

### Presence Checks

```dart
bool hasName = req.has('name');
bool hasAny = req.hasAny(['name', 'email']);

// Conditional execution
req.whenHas('avatar', (value) {
  // process avatar
});
```

### Merging Data

```dart
// Override or add data
req.merge({'role': 'admin'});

// Add only if key doesn't already exist
req.mergeIfMissing({'role': 'user'});
```

## Query Parameters

```dart
// All query parameters
Map<String, dynamic> query = req.query();

// Specific key with default
String page = req.query('page', '1');
```

## Route Parameters

Route parameters from `{param}` segments are available via `params()`:

```dart
// Route: /users/{id}/posts/{postId}
Map<String, dynamic> params = req.params();
int userId = params['id'];
int postId = params['postId'];
```

Route parameters are also automatically injected into controller method signatures — see [Controllers](controllers.md).

## Headers

```dart
String? contentType = req.header('content-type');
String auth = req.header('authorization', 'none');

// All headers
var headers = req.headers;
```

### Request Metadata

```dart
String ip = req.ip;
String method = req.method;
String path = req.path;
String url = req.url;
String host = req.host;
String? userAgent = req.userAgent();
String? origin = req.origin();
String? referer = req.referer();
String? contentType = req.contentType;
```

### Request Type Checks

```dart
bool isJson = req.isJson();
bool isForm = req.isFormData();
bool isUrlencoded = req.isUrlencoded();
bool isGet = req.isMethod('GET');
```

## File Uploads

Uploaded files are available through `file()` and `files()`:

```dart
// Single file
RequestFile? avatar = req.file('avatar');
if (avatar != null) {
  String filename = avatar.filename;
  String mimeType = avatar.mimeType;
  List<int> bytes = avatar.bytes;

  // Save to storage
  await Storage.put('avatars/$filename', bytes);
}

// Multiple files
List<RequestFile> photos = req.files('photos');

// Check presence
bool hasFile = req.hasFile('avatar');
```

## Cookies

```dart
String? sessionId = req.cookie<String>('session_id');
int? visits = req.cookie<int>('visit_count');
```

## Validation

Validate request data inline. On failure, a `ValidationException` is thrown with detailed error messages.

```dart
Future<Response> store(Request req) async {
  // String-based rules
  req.validate({
    'title': 'required|string|max_length:255',
    'body': 'required|string',
    'email': 'required|email|unique:users',
    'tags': 'array',
    'tags.*': 'string|max_length:50',
  });

  // Data is valid — proceed
  final post = await Post().query.create(req.only(['title', 'body', 'email']));
  return Response.json(post, 201);
}
```

See [Validation](validation.md) for all available rules and approaches.

## JSON Input

Parse a specific field as JSON:

```dart
Map<String, dynamic> metadata = req.json('metadata');
```

## Authenticated User

If the authentication package is installed and the route uses auth middleware:

```dart
var user = req.user;
```

The `user` getter calls a resolver installed by the auth package. Without auth middleware, this returns `null`.
