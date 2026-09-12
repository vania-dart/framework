---
sidebar_position: 12
---

# Storage

Vania provides a unified API for file storage with two built-in drivers: local filesystem and Amazon S3.

## Configuration

The active driver is chosen by the `STORAGE` environment variable — not the config map. It is `local` by default:

```env
STORAGE=local
```

To use Amazon S3, set `STORAGE=s3` and supply the S3 credentials via their own keys:

```env
STORAGE=s3
STORAGE_S3_REGION=us-east-1
STORAGE_S3_BUCKET=my-bucket
STORAGE_S3_ACCESS_KEY=...
STORAGE_S3_SECRET_KEY=...
```

The API below is identical regardless of which driver is active.

## Basic Usage

```dart
import 'package:vania/vania.dart';

// Store a file (returns the stored path)
await Storage.put('avatars/user_42.png', imageBytes);

// Read a file's contents as text
String? text = await Storage.get('notes/todo.txt');

// Read a file as raw bytes
Uint8List? bytes = await Storage.getAsBytes('avatars/user_42.png');

// Check if a file exists
bool exists = await Storage.exists('avatars/user_42.png');

// Delete a file
await Storage.delete('avatars/user_42.png');

// Get file metadata
String? mime = await Storage.mimeType('avatars/user_42.png');
int? size = await Storage.size('avatars/user_42.png');

// Read as JSON
Map<String, dynamic>? data = await Storage.json('config/settings.json');
```

## Handling File Uploads

Combine with the request's file access:

```dart
Future<Response> uploadAvatar(Request req) async {
  final file = req.file('avatar');
  if (file == null) {
    return Response.json({'error': 'No file provided'}, 400);
  }

  final path = 'avatars/${DateTime.now().millisecondsSinceEpoch}_${file.filename}';
  await Storage.put(path, file.bytes);

  return Response.json({'path': path}, 201);
}
```

## Switching Disks

The `Storage` facade uses the default disk. To use a specific disk, configure and switch in your storage setup.

## Path Helpers

```dart
import 'package:vania/vania.dart';

String path = storagePath('app/uploads/file.txt');
// Returns the full filesystem path to storage/app/uploads/file.txt
```
