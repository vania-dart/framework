import 'dart:io';

import 'package:vania/env.dart' show env;

/// How many isolates serve HTTP, from `APP_ISOLATES`: a number, or `auto`
/// for one per CPU core. Defaults to 1.
///
/// Each isolate has its own memory, so anything kept in memory is per
/// isolate: rate-limit counters, WebSocket rooms, and whatever an app
/// holds in a static field. The session cache is switched off when this
/// is above 1, since one isolate would otherwise serve a session that
/// another has since changed.
final int serverIsolateCount = _resolveIsolateCount();

int _resolveIsolateCount() {
  final raw = env<String?>('APP_ISOLATES', null)?.trim().toLowerCase();
  if (raw == null || raw.isEmpty) return 1;
  if (raw == 'auto') return Platform.numberOfProcessors;
  final count = int.tryParse(raw);
  return (count == null || count < 1) ? 1 : count;
}

/// How long a shutdown waits for in-flight requests before closing the
/// connections that remain, from `SHUTDOWN_TIMEOUT` in seconds.
Duration get shutdownTimeout =>
    Duration(seconds: env<int>('SHUTDOWN_TIMEOUT', 10));
