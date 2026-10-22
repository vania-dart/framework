import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// With `APP_ISOLATES`, every isolate but the first starts without running
/// `main()`; the app's `setup` is what reaches all of them.
void main() {
  late Process server;
  late int port;

  setUpAll(() async {
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    port = probe.port;
    await probe.close();

    server = await Process.start(
      Platform.resolvedExecutable,
      ['test/fixtures/isolate_setup_app.dart'],
      environment: {
        'APP_KEY': 'kQ1spu2E1r452fLa7cSihi7p1pdBR7040H8-UxtXNXg8=',
        'APP_ISOLATES': '2',
        'APP_HOST': '127.0.0.1',
        'APP_PORT': '$port',
        'APP_DEBUG': 'false',
      },
    );
    server.stdout.drain<void>();
    server.stderr.drain<void>();
  });

  tearDownAll(() async {
    server.kill(ProcessSignal.sigterm);
    await server.exitCode.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        server.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
  });

  /// What one isolate reports, over a connection of its own so that the
  /// requests spread over the isolates.
  Future<Map<String, dynamic>?> ask() async {
    final client = HttpClient();
    try {
      final res = await (await client.get('127.0.0.1', port, '/setup')).close();
      return jsonDecode(await res.transform(utf8.decoder).join())
          as Map<String, dynamic>;
    } on SocketException {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  test('setup runs in every isolate, main() only in the first', () async {
    final answers = <String, Map<String, dynamic>>{};
    final waited = Stopwatch()..start();
    while (answers.length < 2 && waited.elapsed < const Duration(seconds: 60)) {
      final answer = await ask();
      if (answer == null) {
        // Still starting.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        continue;
      }
      answers[answer['isolate'].toString()] = answer;
    }

    expect(answers, hasLength(2), reason: 'both isolates answered');
    for (final answer in answers.values) {
      expect(answer['setup'], isTrue, reason: '$answer');
    }
    // What a worker misses without setup: the code in main().
    expect(answers.values.where((a) => a['main'] == true), hasLength(1));
  }, timeout: const Timeout(Duration(seconds: 90)));
}
