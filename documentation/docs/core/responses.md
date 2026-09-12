---
sidebar_position: 4
---

# Responses

Every controller method returns a `Response` that the framework writes to the HTTP connection. Vania provides factory methods for every common response type.

## JSON Response

The most common response for APIs:

```dart
return Response.json({'id': 1, 'name': 'Alice'});

// With custom status code
return Response.json({'message': 'Created'}, 201);
```

### JSON with Custom Headers

```dart
return Response.jsonWithHeader(
  {'data': items},
  statusCode: 200,
  headers: {
    'X-Total-Count': '42',
    'X-Page': '1',
  },
);
```

## HTML Response

Return raw HTML or rendered templates:

```dart
return Response.html('<h1>Welcome</h1>');

// With custom headers
return Response.html(
  '<h1>Hello</h1>',
  headers: {'X-Custom': 'value'},
);
```

## View Response

Render a template file from the `views/` directory:

```dart
import 'package:vania/http/response.dart';

return view('welcome', {'name': 'Alice'});
```

This uses the template engine to process the file and returns an HTML response. See [Views & Templates](views-templates.md) for the template syntax.

## Redirect

```dart
return Response.redirect('/login');
```

### Redirect Back

Return the user to the previous page:

```dart
return Response.back();

// With a flash message
return Response.back('status', 'Profile updated');

// Redirect back and flash an error under a key
return Response.backWithInput('email', 'That address is already taken');
```

## File Responses

### Stream a File

Sends a file inline (the browser displays it if possible):

```dart
return Response.file('report.pdf', fileBytes);
```

### Download a File

Forces a download with `Content-Disposition: attachment`:

```dart
return Response.download('report.pdf', fileBytes);

// With custom headers
return Response.download(
  'export.csv',
  csvBytes,
  headers: {'X-Generated': DateTime.now().toIso8601String()},
);
```

## Server-Sent Events (SSE)

Stream real-time events to the client:

```dart
return Response.sse(eventStream);
```

Where `eventStream` is a `Stream` that yields data the framework writes as SSE events.

```dart
Future<Response> notifications(Request req) async {
  final stream = Stream.periodic(
    Duration(seconds: 5),
    (i) => {'event': 'ping', 'count': i},
  );

  return Response.sse(stream);
}
```

## Empty / No Content

Return an empty 204 response:

```dart
return Response.json(null, 204);
```

## Response Status Codes

The second argument to `Response.json()` sets the HTTP status code:

```dart
Response.json(data, 200);  // OK (default)
Response.json(data, 201);  // Created
Response.json(data, 204);  // No Content
Response.json(error, 400); // Bad Request
Response.json(error, 401); // Unauthorized
Response.json(error, 403); // Forbidden
Response.json(error, 404); // Not Found
Response.json(error, 422); // Unprocessable Entity
Response.json(error, 500); // Internal Server Error
```
