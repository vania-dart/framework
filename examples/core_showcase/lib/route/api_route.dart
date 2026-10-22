import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:vania/http/middleware.dart';
import 'package:vania/http/request.dart';
import 'package:vania/http/response.dart';
import 'package:vania/route.dart';
import 'package:vania/vania.dart'
    show
        InternalServerError,
        NotFoundException,
        Unauthenticated,
        ValidationException;

import '../app/middleware.dart';

/// JSON API routes, one block per feature under test. Everything here sits
/// under `api/`, which CSRF protection leaves out.
class ApiRoute extends Route {
  @override
  String? get prefix => 'api';

  @override
  void register() {
    super.register();

    // --- Basics, and a server that survives its handlers' failures.
    Router.get('/json', () => Response.json({'ok': true}));
    Router.get('/crash-after-write', (Request req) async {
      req.response.write('partial');
      await req.response.flush();
      throw StateError('failed after the response started');
    });
    Router.get('/empty', () => Response());
    Router.get('/bad-json', () => Response.json({'when': DateTime(2020)}));

    // A bug in app code: a future nobody waits for fails after the
    // response has gone. Nothing can catch it on the request's behalf.
    Router.get('/stray-error', () {
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 20),
          () => throw StateError('nobody awaited me'),
        ),
      );
      return Response.json({'answered': true});
    });

    // --- Isolates, timeouts, shutdown.
    Router.get(
      '/who',
      () => Response.json({'isolate': Isolate.current.debugName}),
    );
    Router.get('/die', () {
      if (Isolate.current.debugName?.startsWith('vania-http') ?? false) {
        Isolate.exit();
      }
      return Response.json({'isolate': 'main, not killed'});
    });
    Router.get('/sleep/{ms}', (int ms) async {
      await Future<void>.delayed(Duration(milliseconds: ms));
      return Response.json({'slept': ms});
    });

    // --- Request body and accessors.
    Router.post('/upload', (Request req) {
      return Response.json({
        'fields': req.all().keys.toList(),
        'avatarIsFile': req.file('avatar') != null,
      });
    });
    Router.post('/accessors', (Request req) {
      return Response.json({
        'hasAge': req.has('age'),
        'exceptPassword': req.except('password'),
        'passwordStillThere': req.input('password'),
      });
    });
    Router.get(
      '/headers',
      (Request req) => Response.json(req.headers['x-multi']),
    );
    Router.post(
      '/raw',
      (Request req) => Response.json(utf8.decode(req.rawBody)),
    );
    Router.post('/validate', (Request req) async {
      await req.validate({'email': 'required|email'});
      return Response.json({'valid': true});
    });

    // --- Files, ranges, downloads, events.
    Router.get('/video', () => Response.fromPath('public/docs/sample.bin'));
    Router.get(
      '/download',
      (Request req) => Response.fromPath(
        'public/docs/sample.bin',
        download: true,
        fileName: req.query('name') ?? 'sample.bin',
      ),
    );
    Router.get(
      '/download-bytes',
      (Request req) => Response.download(
        req.query('name') ?? 'bytes.bin',
        Uint8List.fromList(utf8.encode('downloaded')),
      ),
    );
    Router.get('/events', () {
      return Response.sse(
        Stream.periodic(
          const Duration(milliseconds: 700),
          (i) => {'tick': i + 1, 'at': DateTime.now().toIso8601String()},
        ).take(5),
      );
    });

    // --- Routing: constraints, decoding, any, apiResource.
    Router.get('/slug/{s}', (String s) => Response.json(s)).whereString('s');
    Router.get('/price/{x}', (double x) => Response.json(x)).whereDouble('x');
    Router.get('/flag/{b}', (bool b) => Response.json(b)).whereBool('b');
    Router.get(
      '/num/{id}',
      (dynamic id) => Response.json(id),
    ).where('id', r'\d+');
    Router.get(
      '/posts/{slug}',
      (String slug) => Response.json(slug),
    ).whereString('slug');
    Router.get(
      '/مقالات/{id}',
      (int id) => Response.json({'article': id}),
    ).whereInt('id');
    Router.any(
      '/guarded',
      () => Response.json({'secret': 42}),
    ).middleware([DenyAll()]);
    Router.apiResource('/photos', PhotoController());

    // --- QUERY (RFC 10008).
    Router.get('/contacts', () => Response.json({'via': 'GET'}));
    Router.query('/contacts', (Request req) {
      return Response.json({
        'via': 'QUERY',
        'input': req.all(),
        if (req.isJson() == false) 'raw': utf8.decode(req.rawBody),
      });
    }).acceptQuery(['application/json', 'application/sql']);

    // --- Middleware and the response.
    Router.get(
      '/timed',
      () => Response.json({'ok': true}),
    ).middleware([Timing()]);
    Router.get(
      '/twice',
      () => Response.json({'ok': true}),
    ).middleware([CallsNextTwice()]);
    Router.get(
      '/forgets',
      () => Response.json({'ok': true}),
    ).middleware([Forgets()]);
    Router.get(
      '/observed',
      () => throw StateError('controller failed'),
    ).middleware([Observes()]);
    Router.get('/throttled', () => Response.json({'ok': true})).middleware([
      // A short window, so the checker can be run again straight away.
      Throttle(
        maxAttempts: 3,
        duration: const Duration(seconds: 3),
        bypassInDevelopment: false,
      ),
    ]);

    // --- Errors: one policy wherever they are thrown.
    Router.get(
      '/missing-map',
      () => throw NotFoundException(message: {'error': 'no such user'}),
    );
    Router.get(
      '/leaky',
      () => throw InternalServerError(message: 'db password is hunter2'),
    );
    Router.get('/leaky-mw', () => Response.json({})).middleware([
      Throws(() => InternalServerError(message: 'db password is hunter2')),
    ]);
    // A token guard: its message is text, so even a browser gets a 401.
    Router.get(
      '/token-guard',
      () => Response.json({}),
    ).middleware([Throws(() => Unauthenticated(message: 'Unauthenticated'))]);
    Router.get('/validation-mw', () => Response.json({})).middleware([
      Throws(() => ValidationException(message: {'email': 'is required'})),
    ]);
  }
}

/// A JSON resource: no `create` or `edit`.
class PhotoController {
  Response index() => Response.json(['photo 1', 'photo 2']);
  Response store() => Response.json({'stored': true}, HttpStatus.created);
  Response show(int id) => Response.json({'photo': id});
  Response update(int id) => Response.json({'updated': id});
  Response destroy(int id) => Response.json({'destroyed': id});
}
