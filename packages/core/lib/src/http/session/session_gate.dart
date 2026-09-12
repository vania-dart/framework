import 'dart:io';

import 'package:meta/meta.dart';

import 'package:vania/env.dart' show env;

/// Where the view engine resolves templates from. An app that ships no
/// views renders no HTML, so it has no use for a session or a CSRF token.
String _viewDirectory = 'lib/resources/view';

/// Points the gate at a different view directory. Tests use this instead of
/// moving the process working directory, which is shared by every test file
/// running concurrently.
@visibleForTesting
set viewDirectoryForGate(String dir) {
  _viewDirectory = dir;
  resetSessionGate();
}

bool? _cached;

/// True when the session-backed request features — the session cookie, the
/// CSRF token, and route history — should run for this app.
///
/// `SESSION_ENABLED` settles it outright when set. Otherwise it is inferred:
/// an app either ships views, or has CSRF protection switched on, and either
/// way it needs the session bag those features are stored in.
///
/// The inference matters because the alternative is inferring it from the
/// request's `Accept` header, which the client controls. Browsers and
/// crawlers send `Accept: text/html,...` at API endpoints all the time, and
/// every such request that arrives without a session cookie mints a new
/// session id and writes an encrypted file for it. For a service with no
/// views that is pure disk growth with nothing ever reading it back.
bool sessionsEnabled() => _cached ??= _resolve();

bool _resolve() {
  final configured = env<String?>('SESSION_ENABLED', null);
  if (configured != null && configured.trim().isNotEmpty) {
    return bool.tryParse(configured.trim(), caseSensitive: false) ?? true;
  }
  // CSRF tokens live in the session, so protection cannot work without one
  // even for an app that renders no views of its own.
  if (env<bool>('CSRF_PROTECTION_ENABLED', false)) return true;
  return Directory(_viewDirectory).existsSync();
}

/// Forgets the cached answer. Tests that add or remove the view directory,
/// or change `SESSION_ENABLED`, call this so the next request re-resolves.
void resetSessionGate() => _cached = null;
