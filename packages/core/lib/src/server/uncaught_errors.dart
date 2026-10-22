import 'dart:isolate';

import '../logger/logger.dart';

/// Keeps this isolate serving when app code leaves an error unhandled —
/// a future nobody awaited that fails later, say.
///
/// Such an error belongs to no request, so no handler can catch it, and by
/// default it stops the isolate: every request it is serving, and in the
/// main isolate the whole process. Instead it is logged, when [log] is
/// set, and the isolate carries on. A server isolate started by another
/// passes `log: false`, since its errors already reach the log through
/// the isolate that started it.
void keepServingOnUncaughtErrors({required bool log}) {
  if (log) {
    final errors = ReceivePort();
    errors.listen((message) {
      final [error, stack] = message as List;
      Logger.log('Uncaught error: $error\n$stack', type: Logger.ERROR);
    });
    Isolate.current.addErrorListener(errors.sendPort);
  }
  Isolate.current.setErrorsFatal(false);
}
