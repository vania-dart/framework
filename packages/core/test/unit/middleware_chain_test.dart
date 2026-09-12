import 'package:test/test.dart';
import 'package:vania/src/http/middleware/middleware.dart';
import 'package:vania/src/http/middleware/middleware_handler.dart';
import 'package:vania/src/http/request/request.dart';

/// Records the order in which chain participants run.
final List<String> log = [];

/// Only overrides `handle` — the shape every existing middleware uses.
class _Legacy extends Middleware {
  _Legacy(this.name, {this.fail = false});
  final String name;
  final bool fail;

  @override
  Future<void> handle(Request req) async {
    log.add(name);
    if (fail) throw StateError('$name rejected');
  }
}

/// Overrides `process`, so it can act on both sides of the chain.
class _Wrapping extends Middleware {
  _Wrapping(this.name, {this.callNext = true});
  final String name;
  final bool callNext;

  @override
  Future<void> process(Request req, Next next) async {
    log.add('$name:before');
    if (callNext) await next();
    log.add('$name:after');
  }
}

void main() {
  setUp(log.clear);

  Future<void> run(List<Middleware> chain) =>
      middlewareHandler(chain, Request(), () async => log.add('controller'));

  test('handle-only middleware runs in order, then the controller', () async {
    await run([_Legacy('a'), _Legacy('b')]);
    expect(log, equals(['a', 'b', 'controller']));
  });

  test('process middleware wraps the rest of the chain', () async {
    await run([_Wrapping('outer'), _Legacy('inner')]);
    expect(log, equals(['outer:before', 'inner', 'controller', 'outer:after']));
  });

  test('the two styles compose', () async {
    await run([_Legacy('first'), _Wrapping('mid'), _Legacy('last')]);
    expect(
      log,
      equals(['first', 'mid:before', 'last', 'controller', 'mid:after']),
    );
  });

  test('not calling next skips the controller and later middleware', () async {
    await run([_Wrapping('gate', callNext: false), _Legacy('never')]);
    expect(log, equals(['gate:before', 'gate:after']));
    expect(log, isNot(contains('controller')));
    expect(log, isNot(contains('never')));
  });

  test('a throwing middleware aborts the chain', () async {
    await expectLater(
      run([_Legacy('a'), _Legacy('b', fail: true), _Legacy('c')]),
      throwsA(isA<StateError>()),
    );
    expect(log, equals(['a', 'b']));
    expect(log, isNot(contains('controller')));
  });

  test('a throw propagates out through a wrapping middleware', () async {
    await expectLater(
      run([_Wrapping('outer'), _Legacy('boom', fail: true)]),
      throwsA(isA<StateError>()),
    );
    // `outer:after` is absent: the exception unwound past it.
    expect(log, equals(['outer:before', 'boom']));
  });

  test('an empty chain still reaches the controller', () async {
    await run([]);
    expect(log, equals(['controller']));
  });

  test('each middleware runs exactly once', () async {
    await run([_Wrapping('w'), _Legacy('a'), _Legacy('b')]);
    expect(log.where((e) => e == 'a').length, equals(1));
    expect(log.where((e) => e == 'controller').length, equals(1));
  });
}
