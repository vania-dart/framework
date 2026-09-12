import 'dart:convert';

/// Pure-string Swagger-UI HTML renderer.
///
/// No `HttpServer.bind`, no static-asset serving — just returns the HTML.
/// The controller writes it into a `Response.html(...)`.
class SwaggerPageRenderer {
  const SwaggerPageRenderer._();

  /// Render the Swagger UI HTML pointing at [specUrl].
  ///
  /// Uses the swagger-ui-dist bundle from unpkg. The Dart harness doesn't
  /// ship the JS bundle so the client fetches it at load time — same as
  /// NestJS's default Swagger module.
  static String render({
    required String specUrl,
    String title = 'API Documentation',
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${_htmlEscape(title)}</title>
  <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui.css">
  <style>
    html { box-sizing: border-box; overflow-y: scroll; }
    *, *:before, *:after { box-sizing: inherit; }
    body { margin: 0; background: #fafafa; }
    .swagger-ui .topbar { display: none; }
    .swagger-ui .info { margin: 20px 0; }
    .swagger-ui .info .title { font-size: 1.5em; }
    .swagger-ui .scheme-container { background: none; }
  </style>
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui-bundle.js"></script>
  <script src="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui-standalone-preset.js"></script>
  <script>
    window.onload = function() {
      SwaggerUIBundle({
        url: ${jsonEncode(specUrl)},
        dom_id: '#swagger-ui',
        presets: [
          SwaggerUIBundle.presets.apis,
          SwaggerUIStandalonePreset
        ],
        layout: "BaseLayout",
        deepLinking: true,
        displayRequestDuration: true,
        docExpansion: "list",
        filter: true,
        showExtensions: true,
        showCommonExtensions: true,
        tryItOutEnabled: true,
        persistAuthorization: true,
      });
    };
  </script>
</body>
</html>
''';
  }

  static String _htmlEscape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }
}
