import 'dart:isolate';

import 'package:vania/http/response.dart';
import 'package:vania/route.dart';
import 'package:vania/service_provider.dart';
import 'package:vania/vania.dart';

/// Set by the app's setup, in whichever isolate runs it.
bool _setupRan = false;

/// Set in `main()`, which only the first isolate runs.
bool _mainRan = false;

class _Routes extends ServiceProvider {
  @override
  Future<void> register() async {
    Router.get(
      '/setup',
      () => Response.json({
        'isolate': Isolate.current.debugName,
        'setup': _setupRan,
        'main': _mainRan,
      }),
    );
  }

  @override
  Future<void> boot() async {}
}

/// A server for `isolate_setup_test.dart`, configured through the
/// environment it is started with.
void main() async {
  _mainRan = true;
  await Application().initialize(
    config: {
      'providers': <ServiceProvider>[_Routes()],
    },
    setup: () => _setupRan = true,
  );
}
