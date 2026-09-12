import 'dart:io';

import 'package:meta/meta.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;

import 'package:vania/env.dart' show env;

/// Directory static assets are served from.
String _publicRoot = 'public';

/// Points the static handler at a different root. Tests use this instead of
/// moving the process working directory, which is shared by every test file
/// running concurrently.
@visibleForTesting
set staticPublicRoot(String root) {
  _publicRoot = root;
  resetStaticPathCache();
}

/// Serves a file from `public/` for GET requests whose URI does not end
/// with `/`. Returns `true` when the request has been fully handled
/// (headers and body written, connection closed), `false` when routing
/// should continue.
///
/// The file name is matched case-sensitively, so behaviour is the same on
/// case-sensitive and case-insensitive filesystems.
///
/// Paths whose segments begin with a dot are never served: `.env`,
/// `.git/config` and similar are not web assets even when they happen to
/// sit under `public/`.
///
/// Dot segments in the request path (`..`) are already collapsed by
/// `Uri`, so the path cannot escape `public/`.
///
/// Apps with no `public/` directory pay nothing: the directory is stat-ed
/// at most once per [_publicDirRecheck] window and every GET short-circuits
/// on a cached bool until then.
Future<bool> setStaticPathAsync(HttpRequest req) async {
  // Only GET serves static content. Compared against the raw method,
  // which may arrive in either case, without allocating a copy.
  final m = req.method;
  if (m.length != 3 ||
      !(m == 'GET' || m == 'get' || m.toLowerCase() == 'get')) {
    return false;
  }

  // `req.uri.path` is already parsed and decoded by the HTTP layer, so
  // the fast-fail path costs a single `File.exists()`.
  final rawPath = req.uri.path;
  if (rawPath.endsWith('/') && rawPath.length > 1) return false;

  if (!_publicDirAvailable()) return false;

  final String routePath = rawPath == '/' || rawPath.isEmpty
      ? 'index.html'
      : _stripLeadingSlash(rawPath);

  if (_hasHiddenSegment(routePath)) return false;

  final file = File('$_publicRoot/$routePath');
  // Most requests to an app that also serves an API are routed, not static,
  // so this call decides nearly every request and wants to be the cheapest
  // one that can. `existsSync` answers with a bool; `statSync` builds a
  // `FileStat` and costs about twice as much on the miss. Directories
  // answer false here, so they still never get served as files.
  //
  // Both are sync on purpose: the async forms hand the call to the IO
  // thread pool, which costs an order of magnitude more and occupies a pool
  // slot that concurrent requests then queue behind.
  if (!file.existsSync()) return false;

  // Only now, for a file that will actually be served, pay for the metadata
  // the validators below need.
  final stat = file.statSync();
  if (stat.type != FileSystemEntityType.file) return false;

  final res = req.response;
  final length = stat.size;

  // HTTP dates carry no sub-second component, so a modified time that keeps
  // its milliseconds would always compare as newer than the date echoed back
  // by the client and no request would ever revalidate.
  final lastModified = _truncateToSeconds(stat.modified.toUtc());
  final etag = _etagFor(stat);

  res.headers
    ..set(HttpHeaders.etagHeader, etag)
    ..set(HttpHeaders.lastModifiedHeader, HttpDate.format(lastModified))
    ..set(HttpHeaders.cacheControlHeader, _cacheControl);

  if (_isFresh(req, etag, lastModified)) {
    res
      ..statusCode = HttpStatus.notModified
      ..headers.contentLength = 0;
    await res.close();
    return true;
  }

  final mime =
      lookupMimeType(path.basename(file.path)) ?? 'application/octet-stream';
  final slash = mime.indexOf('/');
  res.headers.contentType = slash > 0
      ? ContentType(mime.substring(0, slash), mime.substring(slash + 1))
      : ContentType('application', 'octet-stream');
  res.headers.contentLength = length;

  await res.addStream(file.openRead());
  await res.close();
  return true;
}

/// `Cache-Control` sent with every static file.
///
/// `no-cache` does not mean "do not store" — it means "store, but
/// revalidate before reuse". Paired with the validators above that turns a
/// repeat visit into a 304 with no body, while never serving a stale asset.
/// Apps that fingerprint their asset names can trade that for an immutable
/// `max-age` through `STATIC_CACHE_CONTROL`.
final String _cacheControl = env<String>(
  'STATIC_CACHE_CONTROL',
  'no-cache',
);

DateTime _truncateToSeconds(DateTime t) =>
    DateTime.utc(t.year, t.month, t.day, t.hour, t.minute, t.second);

/// A validator derived from the file's size and modified time. Hashing the
/// bytes would be a stronger guarantee but would mean reading every file on
/// every request, which is what these headers exist to avoid.
String _etagFor(FileStat stat) {
  final mtime = stat.modified.millisecondsSinceEpoch.toRadixString(16);
  final size = stat.size.toRadixString(16);
  return 'W/"$size-$mtime"';
}

/// Whether the client already holds this exact version.
///
/// `If-None-Match` wins when both validators are present: an entity tag is
/// exact, while a date can only say "not newer than this second".
bool _isFresh(HttpRequest req, String etag, DateTime lastModified) {
  final inm = req.headers.value(HttpHeaders.ifNoneMatchHeader);
  if (inm != null) return _etagMatches(inm, etag);

  final ims = req.headers.value(HttpHeaders.ifModifiedSinceHeader);
  if (ims == null) return false;
  try {
    return !lastModified.isAfter(HttpDate.parse(ims));
  } on HttpException {
    // An unparseable date is treated as absent rather than as a match, so a
    // malformed header can never suppress a real response body.
    return false;
  }
}

/// Compares an `If-None-Match` header against [etag] using the weak
/// comparison RFC 9110 prescribes for GET: the `W/` prefix is ignored, so a
/// weak tag still validates a plain read.
bool _etagMatches(String headerValue, String etag) {
  final candidate = _stripWeakPrefix(etag);
  for (final part in headerValue.split(',')) {
    final trimmed = part.trim();
    if (trimmed == '*') return true;
    if (_stripWeakPrefix(trimmed) == candidate) return true;
  }
  return false;
}

String _stripWeakPrefix(String tag) =>
    tag.startsWith('W/') ? tag.substring(2) : tag;

/// How long a "no `public/` directory" answer is trusted before the
/// directory is stat-ed again, so a `public/` created after boot is still
/// picked up without paying a stat on every request until then.
const Duration _publicDirRecheck = Duration(seconds: 2);

bool _publicDirExists = false;
Stopwatch? _publicDirClock;

/// True when `public/` is present. Once found, the answer is cached for the
/// process: a directory that exists does not stop existing under a running
/// server, and re-checking would reintroduce the per-request stat this
/// gate removes.
bool _publicDirAvailable() {
  if (_publicDirExists) return true;

  final clock = _publicDirClock;
  if (clock != null && clock.elapsed < _publicDirRecheck) return false;

  _publicDirExists = Directory(_publicRoot).existsSync();
  if (!_publicDirExists) {
    _publicDirClock = (clock ?? Stopwatch())
      ..reset()
      ..start();
  }
  return _publicDirExists;
}

/// Forgets the cached `public/` lookup. Tests that create or remove the
/// directory mid-run call this so the next request re-stats it.
void resetStaticPathCache() {
  _publicDirExists = false;
  _publicDirClock = null;
}

/// True when any segment of [p] starts with a dot.
bool _hasHiddenSegment(String p) {
  var start = 0;
  while (start < p.length) {
    if (p.codeUnitAt(start) == 0x2E) return true; // '.'
    final next = p.indexOf('/', start);
    if (next == -1) return false;
    start = next + 1;
  }
  return false;
}

String _stripLeadingSlash(String p) {
  var start = 0;
  final len = p.length;
  while (start < len && p.codeUnitAt(start) == 0x2F) {
    start++;
  }
  return start == 0 ? p : p.substring(start);
}
