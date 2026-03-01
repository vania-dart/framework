import 'src/container.dart';
import 'src/exception/exception_handler.dart';
import 'src/ioc_container.dart';
import 'src/localization_handler/localization.dart';
import 'src/server/base_http_server.dart';
import 'src/env_handler/env.dart';
import 'src/http/request/request_handler.dart';
import 'src/http/session/session_manager.dart';
import 'src/utils/helper.dart' show env;

class Application extends Container {
  static Application? _singleton;

  final Map<Type, ExceptionHandler> _exceptionHandlers = {};
  GeneralExceptionHandler? _generalExceptionHandler;

  factory Application() {
    if (_singleton == null) {
      _singleton = Application._internal();
      Env().load();
      Localization().init();
    }
    return _singleton!;
  }

  Application._internal();

  void addExceptionHandler<T>(ExceptionHandler<T> handler) {
    _exceptionHandlers[T] = handler;
  }

  void setGeneralExceptionHandler(GeneralExceptionHandler handler) {
    _generalExceptionHandler = handler;
  }

  ExceptionHandler? getExceptionHandler(Type type) {
    return _exceptionHandlers[type];
  }

  GeneralExceptionHandler? getGeneralExceptionHandler() {
    return _generalExceptionHandler;
  }

  late BaseHttpServer _server;

  Future<void> initialize({
    required Map<String, dynamic> config,
    List<String> args = const [],
  }) async {
    IoCContainer().register<RequestHandler>(() => RequestHandler());
    IoCContainer().register<SessionManager>(
      () => SessionManager(),
      singleton: true,
    );
    if (env('APP_KEY') == '' || env('APP_KEY') == null) {
      throw Exception('Key not found');
    }

    _server = BaseHttpServer(config: config, args: args);
    _server.startServer();
  }

  Future<void> close() async {
    _server.httpServer?.close();
  }
}
