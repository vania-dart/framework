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

The previous page is taken from the `Referer` header, and only when it points at this same site, so a link from elsewhere cannot use `back()` to redirect off your site. Without one, `back()` from a form post returns to the page at the same path, and from anything else goes to `/` — never to the URL it was called from, which would redirect to itself.

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

### Serve a File from Disk

`Response.file` and `Response.download` send bytes you already hold in memory. For a file on disk — a video, a large export — use `Response.fromPath`, which streams it without loading it into memory:

```dart
return Response.fromPath('storage/videos/intro.mp4');

// Saved by the browser, under a name of your choosing
return Response.fromPath(
  'storage/exports/2026-10.csv',
  download: true,
  fileName: 'october.csv',
);
```

It answers `Range` requests with `206 Partial Content`, so video players can seek and interrupted downloads can resume. A path that is not a file gets a 404.

The path is read as given. Never build it from request input without confining it to a directory you mean to serve.

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

Each event is sent as soon as the stream yields it. While the stream is quiet, a comment line goes out every `SSE_HEARTBEAT` seconds (default 15), which keeps proxies from closing the connection. When the client goes away, the subscription to your stream is cancelled, so a `StreamController`'s `onCancel` is the place to release whatever feeds it. An error from the stream ends the response and is logged.

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
