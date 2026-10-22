import 'dart:async';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:vania/src/server/uncaught_errors.dart';

/// An isolate as a server runs it: it leaves an error unhandled, then
/// reports whether it is still there to serve.
Future<void> _server((SendPort, bool) args) async {
  final (report, guarded) = args;
  if (guarded) keepServingOnUncaughtErrors(log: false);
  unawaited(Future<void>.error(StateError('nobody awaited me')));
  await Future<void>.delayed(const Duration(milliseconds: 100));
  report.send('still serving');
}

Future<Object?> _run({required bool guarded}) async {
  final messages = ReceivePort();
  final exited = ReceivePort();
  await Isolate.spawn(_server, (
    messages.sendPort,
    guarded,
  ), onExit: exited.sendPort);
  final outcome = await Future.any([
    messages.first,
    exited.first.then((_) => 'exited'),
  ]);
  messages.close();
  exited.close();
  return outcome;
}

void main() {
  test('without the guard, an unhandled error stops the isolate', () async {
    expect(await _run(guarded: false), 'exited');
  });

  test('with it, the isolate goes on serving', () async {
    expect(await _run(guarded: true), 'still serving');
  });
}
