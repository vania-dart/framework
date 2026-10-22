import 'dart:async';
import 'dart:convert';
import 'package:vania/src/http/session/flash_messages.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'package:mime/mime.dart';
import 'package:vania/env.dart' show env;
import 'package:vania/src/http/request/request_scope.dart';
import 'package:vania/src/http/response/error_response_writer.dart';
import 'package:vania/src/http/response/stream_file.dart';
import 'package:vania/src/logger/logger.dart';
import 'package:vania/src/route/route_history.dart';

final Utf8Encoder _utf8 = utf8.encoder;

/// How often an event stream sends a comment line while it has nothing
/// else to send, from `SSE_HEARTBEAT` in seconds.
final Duration _sseHeartbeat = Duration(seconds: env<int>('SSE_HEARTBEAT', 15));

/// Encodes straight from the object graph to UTF-8 bytes.
///
/// `utf8.encode(jsonEncode(data))` builds a full intermediate `String` and
/// then walks it again to produce bytes. Going direct skips that middle
/// step, which is worth about a fifth of the encoding time and scales with
/// the payload. Output — including the errors thrown for unsupported and
/// cyclic values — is byte-identical to the two-step form.
final JsonUtf8Encoder _jsonUtf8 = JsonUtf8Encoder();

enum ResponseType { json, none, redirect, html, sse, streamFile, download }

class Response {
  @protected
  final ResponseType responseType;
  @protected
  final dynamic data;
  @protected
  final int httpStatusCode;
  @protected
  final Map<String, String> headers;

  Response({
    this.data,
    this.responseType = ResponseType.none,
    this.httpStatusCode = HttpStatus.ok,
    this.headers = const {},
  });

  @protected
  Future<void> sseHandler(HttpResponse res) async {
    // Buffered, the response holds chunks back even through `flush()`, and
    // an event would only reach the client once 8 KB had piled up.
    res.bufferOutput = false;
    res.headers.contentType = ContentType.parse('text/event-stream');
    res.headers.add(HttpHeaders.cacheControlHeader, 'no-cache');
    res.headers.add(HttpHeaders.connectionHeader, 'keep-alive');
    res.headers.add(HttpHeaders.transferEncodingHeader, 'chunked');

    final finished = Completer<void>();
    void finish() {
      if (!finished.isCompleted) finished.complete();
    }

    // One write at a time: the response refuses a write while a flush is
    // in progress. A failed write means the client has gone — and so does
    // one that does not finish: once the client has left, dart:io neither
    // fails the flush nor completes `done`, it just never returns.
    var writes = Future<void>.value();
    void send(String text) {
      writes = writes.then((_) {
        res.add(utf8.encode(text));
        return res.flush().timeout(_sseHeartbeat);
      });
      writes.catchError((Object _) => finish());
    }

    final events = (data as Stream<dynamic>).listen(null);
    events
      ..onData((event) {
        try {
          send('data: ${jsonEncode(event)}\n\n');
        } catch (e, stack) {
          Logger.log('SSE event not sent: $e\n$stack', type: Logger.ERROR);
          finish();
          return;
        }
        // Holds the source back while a slow client catches up.
        events.pause(writes.catchError((Object _) {}));
      })
      ..onError((Object e, StackTrace stack) {
        Logger.log('SSE event source failed: $e\n$stack', type: Logger.ERROR);
        finish();
      })
      ..onDone(finish);

    // Keeps proxies from closing a quiet connection, and finds out when
    // the client has left even if no event is due.
    final heartbeat = Timer.periodic(_sseHeartbeat, (_) => send(':\n\n'));
    res.done.then((_) => finish(), onError: (Object _) => finish());

    await finished.future;
    heartbeat.cancel();
    await events.cancel();
    // Bounded for the same reason: a response to a client that has left
    // may never finish closing.
    await writes
        .catchError((Object _) {})
        .then((_) => closeQuietly(res))
        .timeout(_sseHeartbeat, onTimeout: () {});
  }

  /// Writes the response to the wire and closes the underlying [HttpResponse].
  ///
  /// Callers must await this: the returned future completes once the
  /// response has been flushed and the connection closed.
  Future<void> makeResponse(HttpResponse res) async {
    // Answered already, by REQUEST_TIMEOUT: nothing more goes out.
    final scope = currentRequestScope;
    if (scope != null && scope.abandoned) return;
    final pending = scope?.runBeforeResponse();
    if (pending != null) await pending;
    res.statusCode = httpStatusCode;
    if (headers.isNotEmpty) {
      headers.forEach((key, value) {
        res.headers.set(key, value);
      });
    }
    switch (responseType) {
      case ResponseType.json:
        res.headers.contentType = ContentType.json;
        List<int> bytes;
        try {
          bytes = _jsonUtf8.convert(data);
        } catch (e, stack) {
          // Nothing is written yet, so the status can still say it failed.
          Logger.log('$e\n$stack', type: Logger.ERROR);
          res.statusCode = HttpStatus.internalServerError;
          bytes = _jsonUtf8.convert({
            'message': env<bool>('APP_DEBUG', false)
                ? e.toString()
                : 'Internal Server Error',
          });
        }
        res.headers.contentLength = bytes.length;
        res.add(bytes);
        await res.close();
        break;
      case ResponseType.html:
        res.headers.contentType = ContentType.html;
        if (data is String) {
          final bytes = _utf8.convert(data);
          res.headers.contentLength = bytes.length;
          res.add(bytes);
        } else {
          res.write(data);
        }
        await res.close();
        break;
      case ResponseType.sse:
        await sseHandler(res);
        break;
      case ResponseType.streamFile:
        StreamFile? stream = StreamFile(
          fileName: data['fileName'],
          bytes: data['bytes'],
        ).call();
        if (stream == null) {
          res.headers.contentType = ContentType.json;
          res.write(jsonEncode({"message": "File not found"}));
          await res.close();
          break;
        }
        res.headers.contentType = stream.contentType;
        res.headers.contentLength = stream.length;
        res.add(stream.bytes);
        await res.close();
        break;
      case ResponseType.download:
        StreamFile? stream = StreamFile(
          fileName: data['fileName'],
          bytes: data['bytes'],
        ).call();
        if (stream == null) {
          res.headers.contentType = ContentType.json;
          res.write(jsonEncode({"message": "File not found"}));
          await res.close();
          break;
        }
        res.headers.contentType = stream.contentType;
        res.headers.contentLength = stream.length;
        res.headers.add("Content-Disposition", stream.contentDisposition);
        res.add(stream.bytes);
        await res.close();
        break;
      case ResponseType.redirect:
        res.headers.set(HttpHeaders.locationHeader, data);
        await res.close();
        break;
      case ResponseType.none:
        if (data != null) res.write(data);
        await res.close();
        break;
    }
  }

  static Response redirect(String location) => Response(
    responseType: ResponseType.redirect,
    data: location,
    httpStatusCode: HttpStatus.found,
  );

  static Response json(dynamic jsonData, [int statusCode = HttpStatus.ok]) =>
      Response(
        data: jsonData,
        responseType: ResponseType.json,
        httpStatusCode: statusCode,
      );

  static Response jsonWithHeader(
    dynamic jsonData, {
    int statusCode = HttpStatus.ok,
    Map<String, String> headers = const {},
  }) => Response(
    data: jsonData,
    responseType: ResponseType.json,
    httpStatusCode: statusCode,
    headers: headers,
  );

  /// [statusCode] defaults to 200.
  static Response html(
    dynamic htmlData, {
    int statusCode = HttpStatus.ok,
    Map<String, String> headers = const {},
  }) => Response(
    data: htmlData,
    responseType: ResponseType.html,
    httpStatusCode: statusCode,
    headers: headers,
  );

  static Response file(
    String fileName,
    Uint8List bytes, {
    Map<String, String> headers = const {},
  }) => Response(
    data: {"fileName": fileName, "bytes": bytes},
    responseType: ResponseType.streamFile,
    headers: headers,
  );

  /// Streams the file at [path] from disk without holding it in memory.
  ///
  /// A single `Range` request is answered with `206 Partial Content`, so
  /// media can be seeked and interrupted downloads resumed. With
  /// [download] the browser saves the file, as [fileName] or by default
  /// under its own name. A path that is not a file gets a 404.
  ///
  /// [path] is read as given: never build it from request input without
  /// confining it to a directory you mean to serve.
  static Response fromPath(
    String path, {
    bool download = false,
    String? fileName,
    Map<String, String> headers = const {},
  }) => _FileResponse(
    path,
    download: download,
    fileName: fileName,
    headers: headers,
  );

  static Response sse(
    Stream<dynamic> eventStream, {
    int statusCode = HttpStatus.ok,
    Map<String, String> headers = const {},
  }) => Response(
    data: eventStream,
    responseType: ResponseType.sse,
    httpStatusCode: statusCode,
    headers: headers,
  );

  static Response download(
    String fileName,
    Uint8List bytes, {
    Map<String, String> headers = const {},
  }) => Response(
    data: {"fileName": fileName, "bytes": bytes},
    responseType: ResponseType.download,
    headers: headers,
  );

  static Response back([String? key, String? message]) {
    if (key != null && message != null) {
      FlashMessages().flash(key, message);
    }
    return Response.redirect(_backUrl());
  }

  static Response backWithInput([String? input, String? message]) {
    if (input != null && message != null) {
      FlashMessages().addError(input, message);
    }
    return Response.redirect(_backUrl());
  }
}

/// Where `back()` sends the client: the page it came from, as far as that
/// can be told safely, and `/` when it cannot.
///
/// The `Referer` header is used only when it names this same site, and
/// only its path and query, so a crafted link cannot turn `back()` into a
/// redirect to somewhere else.
String _backUrl() {
  final history = RouteHistory();
  if (history.previousRoute.isNotEmpty) return history.previousRoute;

  final req = currentRequestScope?.request;
  final host = req?.headers.value(HttpHeaders.hostHeader)?.toLowerCase();
  final referer = Uri.tryParse(
    req?.headers.value(HttpHeaders.refererHeader) ?? '',
  );
  if (host != null && referer != null && referer.hasAuthority) {
    final authority = referer.hasPort
        ? '${referer.host}:${referer.port}'
        : referer.host;
    if (authority.toLowerCase() == host) {
      // `//other.site` would be read as an address on another host.
      final path = '/${referer.path.replaceFirst(RegExp('^/+'), '')}';
      return referer.hasQuery ? '$path?${referer.query}' : path;
    }
  }

  // The current path is a page to go back to only from a form post: a GET
  // sent back to its own URL would answer itself with a redirect forever.
  final method = req?.method.toUpperCase();
  if (history.currentRoute.isNotEmpty && method != 'GET' && method != 'HEAD') {
    return history.currentRoute;
  }
  return '/';
}

/// The answer to a `Range` header no byte of the file satisfies.
const (int, int) _unsatisfiable = (-1, -1);

class _FileResponse extends Response {
  final String path;
  final bool download;
  final String? fileName;

  _FileResponse(
    this.path, {
    required this.download,
    required this.fileName,
    super.headers,
  });

  @override
  Future<void> makeResponse(HttpResponse res) async {
    // Answered already, by REQUEST_TIMEOUT: nothing more goes out.
    final scope = currentRequestScope;
    if (scope != null && scope.abandoned) return;
    final pending = scope?.runBeforeResponse();
    if (pending != null) await pending;
    headers.forEach(res.headers.set);

    final file = File(path);
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) {
      return Response.json({
        'message': 'File not found',
      }, HttpStatus.notFound).makeResponse(res);
    }

    final size = stat.size;
    final lastModified = HttpDate.format(stat.modified.toUtc());
    res.headers
      ..contentType = ContentType.parse(
        lookupMimeType(path) ?? 'application/octet-stream',
      )
      ..set(HttpHeaders.acceptRangesHeader, 'bytes')
      ..set(HttpHeaders.lastModifiedHeader, lastModified);
    if (download) {
      res.headers.set(
        'Content-Disposition',
        attachmentDisposition(fileName ?? path),
      );
    }

    final range = _requestedRange(
      currentRequestScope?.request,
      size,
      lastModified,
    );
    if (range == null) {
      res.headers.contentLength = size;
      // A HEAD gets the headers alone, so there is no reason to read the
      // file.
      if (currentRequestScope?.request.method.toUpperCase() != 'HEAD') {
        await res.addStream(file.openRead());
      }
    } else if (range == _unsatisfiable) {
      res
        ..statusCode = HttpStatus.requestedRangeNotSatisfiable
        ..headers.set(HttpHeaders.contentRangeHeader, 'bytes */$size')
        ..headers.contentLength = 0;
    } else {
      final (start, end) = range;
      res
        ..statusCode = HttpStatus.partialContent
        ..headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$size')
        ..headers.contentLength = end - start + 1;
      await res.addStream(file.openRead(start, end + 1));
    }
    await res.close();
  }
}

/// The inclusive byte range [req] asks for in a file of [size] bytes:
/// null to send the whole file, or [_unsatisfiable].
///
/// Only a single range is honoured. Several ranges would need a multipart
/// body; the whole file is a valid answer to that request too.
(int, int)? _requestedRange(HttpRequest? req, int size, String lastModified) {
  final header = req?.headers.value(HttpHeaders.rangeHeader);
  // RFC 10008 §2.8: ranges mean the same for QUERY as for GET.
  final method = req?.method.toUpperCase();
  if (header == null || (method != 'GET' && method != 'QUERY')) return null;

  // `If-Range` asks for the range only if the file is still the version
  // the client has part of; otherwise it wants the new one, whole.
  final ifRange = req!.headers.value(HttpHeaders.ifRangeHeader);
  if (ifRange != null && ifRange != lastModified) return null;

  if (!header.startsWith('bytes=')) return null;
  final spec = header.substring(6).trim();
  if (spec.contains(',')) return null;
  final dash = spec.indexOf('-');
  if (dash < 0) return null;
  final first = spec.substring(0, dash).trim();
  final last = spec.substring(dash + 1).trim();

  if (first.isEmpty) {
    // `bytes=-N`: the last N bytes.
    final suffix = int.tryParse(last);
    if (suffix == null) return null;
    if (suffix == 0 || size == 0) return _unsatisfiable;
    return (suffix >= size ? 0 : size - suffix, size - 1);
  }

  final start = int.tryParse(first);
  final end = last.isEmpty ? size - 1 : int.tryParse(last);
  if (start == null || end == null || end < start) return null;
  if (start >= size) return _unsatisfiable;
  return (start, end < size ? end : size - 1);
}
