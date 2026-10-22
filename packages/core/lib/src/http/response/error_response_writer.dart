import 'dart:io';

import 'response.dart';

/// Writes [response] on an error path.
///
/// An error can surface after the response has already started: headers
/// sent, part of the body flushed, or the client gone. Nothing more can be
/// said to the client then, so the response is closed as it stands rather
/// than letting a second failure escape the request pipeline.
Future<void> sendErrorResponse(HttpResponse res, Response response) async {
  try {
    await response.makeResponse(res);
  } catch (_) {
    await closeQuietly(res);
  }
}

/// Closes [res], ignoring a response that is already closed or whose
/// connection has dropped.
Future<void> closeQuietly(HttpResponse res) async {
  try {
    await res.close();
  } catch (_) {}
}
