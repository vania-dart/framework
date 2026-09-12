import 'package:vania/http/middleware.dart' show Middleware;
import 'package:vania/route.dart' show Router;
import 'package:vania/service_provider.dart';

import 'annotations/annotations.dart' show ApiInfo;
import 'config/swagger_config.dart';
import 'http/swagger_controller.dart';
import 'metadata/swagger_metadata.dart';

/// Wires Swagger UI + the OpenAPI 3.1 spec into a Vania application.
///
/// `register()` seeds `SwaggerMetadata()` with the provider's [info] and
/// [config]. `boot()` mounts three routes on the app's `Router`:
///
/// | Route                    | Response                           |
/// | ------------------------ | ---------------------------------- |
/// | `GET {basePath}`         | Swagger UI HTML                    |
/// | `GET {basePath}/swagger.json` | OpenAPI 3.1 spec as JSON       |
/// | `GET {basePath}/swagger.yaml` | OpenAPI 3.1 spec as YAML       |
///
/// Because those are just Router entries, the Swagger UI shares the app's
/// HTTP port. No second HttpServer.
class SwaggerServiceProvider extends ServiceProvider {
  const SwaggerServiceProvider({
    this.info,
    this.config,
    this.middleware = const [],
  });

  /// Middleware applied to all three doc routes.
  ///
  /// The docs describe every endpoint the API exposes, which is exactly
  /// the reconnaissance an attacker wants. If you enable them outside
  /// development, gate them — e.g. `middleware: [Authenticate()]` or an
  /// IP allow-list.
  final List<Middleware> middleware;

  /// Optional `ApiInfo` to seed `SwaggerMetadata()` with at register-time.
  /// If omitted and app code already called `swaggerInfo(...)`, the prior
  /// value stays.
  final ApiInfo? info;

  /// Optional config override. Falls back to `SwaggerConfig.fromApplication`.
  final SwaggerConfig? config;

  @override
  Future<void> register() async {
    final info = this.info;
    if (info != null) SwaggerMetadata().setApiInfo(info);
  }

  @override
  Future<void> boot() async {
    final resolved = config ?? SwaggerConfig.fromApplication();
    if (!resolved.enabled) return;

    final base = resolved.normalizedBasePath();
    final controller = SwaggerController(resolved);

    Router.get(
      base,
      controller.renderUi,
    ).name('swagger.ui').middleware(middleware);
    Router.get(
      '$base/swagger.json',
      controller.serveJson,
    ).name('swagger.json').middleware(middleware);
    Router.get(
      '$base/swagger.yaml',
      controller.serveYaml,
    ).name('swagger.yaml').middleware(middleware);
  }
}
