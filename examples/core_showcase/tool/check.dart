// Request-level checks against a running core_showcase.
//
//   dart run tool/check.dart              # server already on :8790
//   dart run tool/check.dart --isolates   # starts its own, with APP_ISOLATES
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const host = '127.0.0.1';
var port = 8790;
var passed = 0;
final failures = <String>[];

void report(String name, bool ok, [String detail = '']) {
  if (ok) {
    passed++;
  } else {
    failures.add(name);
  }
  print(
    '${ok ? 'PASS' : 'FAIL'}  $name${detail.isEmpty ? '' : '  —  $detail'}',
  );
}

Future<void> check(
  String name,
  Future<(bool, String)> Function() body, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  try {
    final (ok, detail) = await body().timeout(timeout);
    report(name, ok, detail);
  } catch (e) {
    report(name, false, 'threw $e');
  }
}

/// A plain HTTP exchange, sent exactly as written.
class Raw {
  Raw(this.status, this.headers, this.body);
  final int status;
  final Map<String, List<String>> headers;
  final String body;
  String? header(String name) => headers[name.toLowerCase()]?.join(', ');
}

Future<Raw> raw(
  String method,
  String path, {
  Map<String, String> headers = const {},
  List<String> extraHeaderLines = const [],
  List<int>? body,
  bool chunked = false,
}) async {
  final socket = await Socket.connect(host, port);
  final lines = [
    '$method $path HTTP/1.1',
    'Host: $host:$port',
    'Connection: close',
    for (final e in headers.entries) '${e.key}: ${e.value}',
    ...extraHeaderLines,
    if (body != null && !chunked) 'Content-Length: ${body.length}',
    if (chunked) 'Transfer-Encoding: chunked',
  ];
  // Read while writing: a server may answer — a 413, say — and close
  // before the whole body has been sent.
  final bytes = <int>[];
  final received = Completer<void>();
  socket.listen(
    bytes.addAll,
    onError: (_) {
      if (!received.isCompleted) received.complete();
    },
    onDone: () {
      if (!received.isCompleted) received.complete();
    },
    cancelOnError: true,
  );
  socket.done.catchError((_) {});
  try {
    socket.add(utf8.encode('${lines.join('\r\n')}\r\n\r\n'));
    if (body != null) {
      if (chunked) {
        for (var i = 0; i < body.length; i += 65536) {
          // Stop once the server has answered, as curl does: writing on
          // into a socket it has closed brings a reset that can wipe out
          // the answer before it is read.
          if (bytes.isNotEmpty) break;
          final part = body.sublist(i, (i + 65536).clamp(0, body.length));
          socket.add(utf8.encode('${part.length.toRadixString(16)}\r\n'));
          socket.add(part);
          socket.add(utf8.encode('\r\n'));
          await socket.flush();
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        socket.add(utf8.encode('0\r\n\r\n'));
      } else {
        socket.add(body);
      }
    }
    await socket.flush();
  } catch (_) {
    // The server stopped reading; its answer is still on the way.
  }
  // An answer that never comes — a connection whose isolate has died —
  // is no answer.
  await received.future.timeout(const Duration(seconds: 10), onTimeout: () {});
  socket.destroy();
  final text = utf8.decode(bytes, allowMalformed: true);
  final split = text.indexOf('\r\n\r\n');
  if (split < 0) return Raw(0, {}, '');
  final head = text.substring(0, split).split('\r\n');
  final headersOut = <String, List<String>>{};
  for (final line in head.skip(1)) {
    final colon = line.indexOf(':');
    headersOut
        .putIfAbsent(line.substring(0, colon).toLowerCase(), () => [])
        .add(line.substring(colon + 1).trim());
  }
  var bodyText = text.substring(split + 4);
  if (headersOut['transfer-encoding']?.contains('chunked') ?? false) {
    bodyText = _unchunk(bodyText);
  }
  return Raw(int.parse(head.first.split(' ')[1]), headersOut, bodyText);
}

String _unchunk(String s) {
  final out = StringBuffer();
  var i = 0;
  while (true) {
    final eol = s.indexOf('\r\n', i);
    if (eol < 0) break;
    final size = int.tryParse(s.substring(i, eol).trim(), radix: 16) ?? 0;
    if (size == 0) break;
    out.write(s.substring(eol + 2, eol + 2 + size));
    i = eol + 2 + size + 2;
  }
  return out.toString();
}

/// A browser: keeps the cookies it is given.
class Browser {
  final cookies = <String, String>{};

  String get cookieHeader =>
      cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  Future<Raw> send(
    String method,
    String path, {
    String? form,
    String accept = 'text/html',
    String? referer,
  }) async {
    final res = await raw(
      method,
      path,
      headers: {
        'Accept': accept,
        if (cookies.isNotEmpty) 'Cookie': cookieHeader,
        if (referer != null) 'Referer': referer,
        if (form != null) 'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: form == null ? null : utf8.encode(form),
    );
    for (final c in res.headers['set-cookie'] ?? const <String>[]) {
      final pair = c.split(';').first;
      final eq = pair.indexOf('=');
      cookies[pair.substring(0, eq)] = pair.substring(eq + 1);
    }
    return res;
  }

  static String? csrfIn(String html) =>
      RegExp(r'name="_csrf" value="([^"]+)"').firstMatch(html)?.group(1);
}

const sessionCookie = 'showcase_session';
String enc(Map<String, String> form) => form.entries
    .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
    .join('&');

Future<void> main(List<String> args) async {
  if (args.contains('--isolates')) {
    await isolateChecks();
  } else {
    await requestChecks();
  }
  print('\n$passed passed, ${failures.length} failed');
  for (final f in failures) {
    print('  FAILED: $f');
  }
  exit(failures.isEmpty ? 0 : 1);
}

Future<void> requestChecks() async {
  print('— stability');
  await check('server boots with HTTP_BACKLOG= left empty in .env', () async {
    final r = await raw('GET', '/api/json');
    return (r.status == 200, 'status ${r.status}');
  });
  await check(
    'a failure after the response started does not stop the server',
    () async {
      try {
        await raw('GET', '/api/crash-after-write');
      } catch (_) {}
      final r = await raw('GET', '/api/json');
      return (
        r.status == 200 && r.body == '{"ok":true}',
        'next request: ${r.status}',
      );
    },
  );
  await check(
    'a chunked multipart upload over MAX_BODY_SIZE is a 413',
    () async {
      final big = [
        ...utf8.encode(
          '--B\r\nContent-Disposition: form-data; name="note"\r\n\r\n',
        ),
        ...List.filled(2 * 1024 * 1024, 65),
        ...utf8.encode('\r\n--B--\r\n'),
      ];
      final r = await raw(
        'POST',
        '/api/upload',
        headers: {
          'Content-Type': 'multipart/form-data; boundary=B',
          'Accept': 'application/json',
        },
        body: big,
        chunked: true,
      );
      return (r.status == 413, 'status ${r.status}');
    },
  );
  await check(
    'an error app code leaves unhandled does not stop the server',
    () async {
      final r = await raw('GET', '/api/stray-error');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final after = await raw('GET', '/api/json');
      return (
        r.status == 200 && after.status == 200,
        'then GET /api/json → ${after.status}',
      );
    },
  );
  await check('REQUEST_TIMEOUT answers a hung request with a 503', () async {
    final sw = Stopwatch()..start();
    final r = await raw(
      'GET',
      '/api/sleep/6000',
      headers: {'Accept': 'application/json'},
    );
    return (
      r.status == 503 && sw.elapsed.inMilliseconds < 4500,
      'status ${r.status} after ${sw.elapsed.inMilliseconds} ms',
    );
  });

  print('— request and response');
  await check('multipart: fields read, a text field is not a file', () async {
    final body = utf8.encode(
      '--B\r\nContent-Disposition: form-data; name="avatar"\r\n\r\nnot a file\r\n'
      '--B\r\nContent-Disposition: form-data; name="doc"; filename="a.txt"\r\nContent-Type: text/plain\r\n\r\nhello\r\n--B--\r\n',
    );
    final r = await raw(
      'POST',
      '/api/upload',
      headers: {
        'Content-Type': 'multipart/form-data; boundary=B',
        'Accept': 'application/json',
      },
      body: body,
    );
    final b = jsonDecode(r.body);
    return (
      r.status == 200 &&
          b['avatarIsFile'] == false &&
          (b['fields'] as List).contains('doc'),
      r.body,
    );
  });
  await check('has() on a number, except() leaves the input alone', () async {
    final r = await raw(
      'POST',
      '/api/accessors',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: utf8.encode('{"age":30,"user":"a","password":"x"}'),
    );
    final b = jsonDecode(r.body);
    return (
      b['hasAge'] == true &&
          !(b['exceptPassword'] as Map).containsKey('password') &&
          b['passwordStillThere'] == 'x',
      r.body,
    );
  });
  await check('a header sent on two lines reads "a, b"', () async {
    final r = await raw(
      'GET',
      '/api/headers',
      headers: {'Accept': 'application/json'},
      extraHeaderLines: ['X-Multi: a', 'X-Multi: b'],
    );
    return (r.body == '"a, b"', r.body);
  });
  await check('Request.rawBody', () async {
    final r = await raw(
      'POST',
      '/api/raw',
      headers: {'Content-Type': 'text/plain', 'Accept': 'application/json'},
      body: utf8.encode('just text'),
    );
    return (r.body == '"just text"', r.body);
  });
  await check('Response() with no data has an empty body', () async {
    final r = await raw('GET', '/api/empty');
    return (
      r.status == 200 && r.body.isEmpty,
      'status ${r.status}, body "${r.body}"',
    );
  });
  await check('an unencodable JSON response is a 500', () async {
    final r = await raw('GET', '/api/bad-json');
    return (
      r.status == 500 && r.body == '{"message":"Internal Server Error"}',
      '${r.status} ${r.body}',
    );
  });
  await check('SSE: every event arrives, even past REQUEST_TIMEOUT', () async {
    // 5 events 700 ms apart: 3.5 s, past the sample's 3 s REQUEST_TIMEOUT.
    final r = await raw('GET', '/api/events');
    final ticks = RegExp(
      r'"tick":(\d+)',
    ).allMatches(r.body).map((m) => m.group(1)).join(',');
    return (ticks == '1,2,3,4,5', 'ticks $ticks');
  });
  await check('SSE: the first event arrives at once, not at the end', () async {
    final socket = await Socket.connect(host, port);
    socket.write(
      'GET /api/events HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n',
    );
    final sw = Stopwatch()..start();
    final firstAt = Completer<int>();
    final sub = socket.listen((d) {
      if (!firstAt.isCompleted &&
          utf8.decode(d, allowMalformed: true).contains('data:')) {
        firstAt.complete(sw.elapsedMilliseconds);
      }
    });
    final ms = await firstAt.future;
    await sub.cancel();
    socket.destroy();
    return (ms < 1500, 'first event after $ms ms (5 events, 700 ms apart)');
  });

  print('— routing');
  final routes = <(String, int, String?)>[
    ('/api/slug/2024', 200, '"2024"'),
    ('/api/price/5', 200, '5.0'),
    ('/api/price/abc', 404, null),
    ('/api/flag/TRUE', 200, 'true'),
    ('/api/flag/yes', 404, null),
    ('/api/num/123', 200, '123'),
    ('/api/num/abc123', 404, null),
    ('/api/posts/c++', 200, '"c++"'),
    ('/api/posts/a%2Fb', 200, '"a/b"'),
    ('/api/posts/%D8%B3%D9%84%D8%A7%D9%85', 200, '"سلام"'),
    ('/api/posts/%E0%A4%A', 404, null),
    ('/api/${Uri.encodeComponent('مقالات')}/7', 200, '{"article":7}'),
  ];
  for (final (path, status, body) in routes) {
    await check('GET $path → $status${body == null ? '' : ' $body'}', () async {
      final r = await raw('GET', path, headers: {'Accept': 'application/json'});
      return (
        r.status == status && (body == null || r.body == body),
        '${r.status} ${r.body}',
      );
    });
  }
  await check(
    'apiResource: index, store, show, update (PUT + PATCH), destroy',
    () async {
      final got = <String>[];
      for (final (m, p) in [
        ('GET', '/api/photos'),
        ('POST', '/api/photos'),
        ('GET', '/api/photos/3'),
        ('PUT', '/api/photos/3'),
        ('PATCH', '/api/photos/3'),
        ('DELETE', '/api/photos/3'),
      ]) {
        got.add(
          '${(await raw(m, p, headers: {'Accept': 'application/json'})).status}',
        );
      }
      return (got.join(',') == '200,201,200,200,200,200', got.join(','));
    },
  );
  await check('apiResource has no create or edit page', () async {
    final a = (await raw('GET', '/api/photos/create')).status;
    final b = (await raw('GET', '/api/photos/3/edit')).status;
    return (a == 404 && b == 404, '$a, $b');
  });
  await check('HEAD on a static file: headers only', () async {
    final r = await raw('HEAD', '/my%20file.css');
    return (
      r.status == 200 && r.body.isEmpty && r.header('content-length') == '19',
      'status ${r.status}, length ${r.header('content-length')}',
    );
  });

  print('— static files never leak');
  for (final path in [
    '/%2E%2E/secret.txt',
    '/docs/%2E%2E/%2E%2E/secret.txt',
    '/docs%2F..%2F..%2Fsecret.txt',
    '/..%5Csecret.txt',
    '/%2Ehidden',
    '/docs/%2E%2E/.hidden',
  ]) {
    await check('GET $path stays inside public/', () async {
      final r = await raw('GET', path);
      return (
        r.status != 200 &&
            !r.body.contains('outside public') &&
            !r.body.contains('APP_KEY'),
        'status ${r.status}',
      );
    });
  }

  print('— middleware');
  await check(
    'calling next() twice is a 500, not a second controller run',
    () async {
      final r = await raw(
        'GET',
        '/api/twice',
        headers: {'Accept': 'application/json'},
      );
      return (r.status == 500, 'status ${r.status}');
    },
  );
  await check('a middleware that forgets to answer: 500, not a hang', () async {
    final r = await raw(
      'GET',
      '/api/forgets',
      headers: {'Accept': 'application/json'},
    );
    return (r.status == 500, 'status ${r.status}');
  });
  await check(
    'Throttle: 200 ×3 then 429; Remaining 2,1,0,0; one Reset',
    () async {
      // The window is 3 s; a run just before this one may still be in it.
      await Future<void>.delayed(const Duration(milliseconds: 3100));
      final statuses = <int>[], remaining = <String?>[], resets = <String?>{};
      String? retry;
      for (var i = 0; i < 4; i++) {
        final r = await raw(
          'GET',
          '/api/throttled',
          headers: {'Accept': 'application/json'},
        );
        statuses.add(r.status);
        remaining.add(r.header('x-ratelimit-remaining'));
        resets.add(r.header('x-ratelimit-reset'));
        retry = r.header('retry-after') ?? retry;
      }
      return (
        statuses.join(',') == '200,200,200,429' &&
            remaining.join(',') == '2,1,0,0' &&
            resets.length == 1 &&
            retry != null,
        'statuses $statuses, remaining $remaining, resets ${resets.length}, Retry-After $retry',
      );
    },
  );

  print('— errors');
  await check('NotFoundException with a map keeps 404 and its body', () async {
    final r = await raw(
      'GET',
      '/api/missing-map',
      headers: {'Accept': 'application/json'},
    );
    return (
      r.status == 404 && r.body == '{"error":"no such user"}',
      '${r.status} ${r.body}',
    );
  });
  await check(
    'a ValidationException from middleware: 422 for an API',
    () async {
      final r = await raw(
        'GET',
        '/api/validation-mw',
        headers: {'Accept': 'application/json'},
      );
      return (r.status == 422, '${r.status} ${r.body}');
    },
  );
  await check('validate() in a controller: 422 with the errors', () async {
    final r = await raw(
      'POST',
      '/api/validate',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: utf8.encode('{}'),
    );
    return (
      r.status == 422 && r.body.contains('email'),
      '${r.status} ${r.body}',
    );
  });

  print('— sessions, CSRF, flash');
  await check('an id the server never issued is not taken up', () async {
    final r = await raw(
      'GET',
      '/login',
      headers: {
        'Accept': 'text/html',
        'Cookie': '$sessionCookie=chosen-by-attacker',
      },
    );
    final issued = (r.headers['set-cookie'] ?? []).firstWhere(
      (c) => c.startsWith('$sessionCookie='),
      orElse: () => '',
    );
    return (
      issued.isNotEmpty && !issued.contains('chosen-by-attacker'),
      issued.split(';').first,
    );
  });
  await check(
    'signing in moves the session to a new id; the old one ends',
    () async {
      final b = Browser();
      final page = await b.send('GET', '/login');
      final before = b.cookies[sessionCookie];
      final token = Browser.csrfIn(page.body);
      final login = await b.send(
        'POST',
        '/login',
        form: enc({'_csrf': token ?? ''}),
      );
      final after = b.cookies[sessionCookie];
      final dash = await b.send('GET', '/dashboard');
      final old = await raw(
        'GET',
        '/dashboard',
        headers: {'Accept': 'text/html', 'Cookie': '$sessionCookie=$before'},
      );
      final ok =
          login.status == 302 &&
          login.header('location') == '/dashboard' &&
          before != after &&
          dash.status == 200 &&
          old.status == 302;
      return (
        ok,
        'login ${login.status} → ${login.header('location')}, id changed: ${before != after}, dashboard ${dash.status}, old id → ${old.status} ${old.header('location')}',
      );
    },
  );
  await check('a form post without the CSRF token is a 419 page', () async {
    final b = Browser();
    await b.send('GET', '/form');
    final r = await b.send(
      'POST',
      '/form',
      form: enc({'name': 'Ann', 'email': 'a@b.c'}),
    );
    return (
      r.status == 419 && r.body.contains("the app's own errors/419"),
      'status ${r.status}',
    );
  });
  await check(
    'validation errors and old input survive the redirect, once; no password',
    () async {
      final b = Browser();
      final page = await b.send('GET', '/form');
      final token = Browser.csrfIn(page.body)!;
      final post = await b.send(
        'POST',
        '/form',
        referer: 'http://$host:$port/form',
        form: enc({
          '_csrf': token,
          'name': 'Ann',
          'email': 'not-an-email',
          'password': 'secret123',
        }),
      );
      final back = await b.send('GET', '/form');
      final again = await b.send('GET', '/form');
      final errorShown = RegExp(r'id="email-error">[^<]+<').hasMatch(back.body);
      final oldName = back.body.contains('value="Ann"');
      final noPassword = !back.body.contains('secret123');
      final gone = !RegExp(r'id="email-error">[^<]+<').hasMatch(again.body);
      return (
        post.status == 302 &&
            post.header('location') == '/form' &&
            errorShown &&
            oldName &&
            noPassword &&
            gone,
        'POST ${post.status} → ${post.header('location')}, error shown $errorShown, old name $oldName, password hidden $noPassword, gone next time $gone',
      );
    },
  );
  await check('a flash message reaches the next page, once', () async {
    final b = Browser();
    final page = await b.send('GET', '/form');
    final token = Browser.csrfIn(page.body)!;
    await b.send(
      'POST',
      '/form',
      referer: 'http://$host:$port/form',
      form: enc({'_csrf': token, 'name': 'Ann', 'email': 'ann@example.com'}),
    );
    final next = await b.send('GET', '/form');
    final after = await b.send('GET', '/form');
    final shown = next.body.contains('Saved — thank you!');
    final gone = !after.body.contains('Saved — thank you!');
    return (shown && gone, 'shown $shown, gone after $gone');
  });
  await check(
    'back() follows a same-site Referer and ignores another site',
    () async {
      final same = await raw(
        'GET',
        '/back',
        headers: {
          'Accept': 'text/html',
          'Referer': 'http://$host:$port/form?x=1',
        },
      );
      final evil = await raw(
        'GET',
        '/back',
        headers: {
          'Accept': 'text/html',
          'Referer': 'https://evil.example/phish',
        },
      );
      return (
        same.header('location') == '/form?x=1' &&
            evil.header('location') == '/',
        'same-site → ${same.header('location')}, other → ${evil.header('location')}',
      );
    },
  );
}

Future<void> isolateChecks() async {
  port = 8791;
  print('— APP_ISOLATES=3, graceful shutdown (server on :$port)');
  final server = await Process.start(
    'dart',
    ['run', 'bin/server.dart', '--port', '$port'],
    environment: {'APP_ISOLATES': '3'},
  );
  server.stdout.drain<void>();
  server.stderr.drain<void>();
  for (var i = 0; i < 60; i++) {
    try {
      if ((await raw('GET', '/api/json')).status == 200) break;
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  Future<Set<String>> isolates() async {
    final seen = <String>{};
    for (var i = 0; i < 60; i++) {
      seen.add(
        jsonDecode((await raw('GET', '/api/who')).body)['isolate'].toString(),
      );
    }
    return seen;
  }

  await check('requests are spread over three isolates', () async {
    final seen = await isolates();
    return (seen.length == 3, '$seen');
  });
  await check('a stray error in a server isolate does not stop it', () async {
    for (var i = 0; i < 10; i++) {
      await raw('GET', '/api/stray-error');
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final seen = await isolates();
    return (seen.length == 3, '$seen');
  });
  await check('a server isolate that dies is replaced', () async {
    for (var i = 0; i < 6; i++) {
      try {
        await raw('GET', '/api/die');
      } catch (_) {}
    }
    // An isolate that keeps dying soon after it starts is retried less
    // and less often (1 s, 2 s, 4 s …), so this can take a while.
    final waited = Stopwatch()..start();
    var seen = <String>{};
    while (waited.elapsed < const Duration(seconds: 50)) {
      seen = await isolates();
      if (seen.length == 3) break;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return (seen.length == 3, '$seen after ${waited.elapsed.inSeconds} s');
  }, timeout: const Duration(seconds: 60));
  await check(
    'SIGTERM: an in-flight request finishes, then the process exits',
    () async {
      final inFlight = raw('GET', '/api/sleep/2000');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      server.kill(ProcessSignal.sigterm);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      // Not served: refused outright, or accepted while closing and left
      // unanswered.
      var refused = false;
      try {
        refused = (await raw('GET', '/api/json')).status == 0;
      } catch (_) {
        refused = true;
      }
      final r = await inFlight;
      final code = await server.exitCode.timeout(const Duration(seconds: 10));
      return (
        r.status == 200 && refused && code == 0,
        'in-flight ${r.status}, new connection refused $refused, exit code $code',
      );
    },
  );
}
