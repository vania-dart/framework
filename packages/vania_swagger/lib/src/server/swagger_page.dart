import 'dart:convert';
import 'dart:io';

import '../generator/swagger_generator.dart';

class SwaggerPage {
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
  <title>$title</title>
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
        url: "$specUrl",
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
      });
    };
  </script>
</body>
</html>
''';
  }

  static void serveSpec({
    required HttpRequest request,
    required SwaggerGenerator generator,
    String? serverUrl,
  }) {
    final spec = generator.generate(serverUrl: serverUrl);
    final json = const JsonEncoder.withIndent('  ').convert(spec);
    request.response
      ..headers.contentType = ContentType.json
      ..headers.add('Access-Control-Allow-Origin', '*')
      ..write(json)
      ..close();
  }

  static void serveUI({
    required HttpRequest request,
    required String specUrl,
    String title = 'API Documentation',
  }) {
    final html = render(specUrl: specUrl, title: title);
    request.response
      ..headers.contentType = ContentType.html
      ..write(html)
      ..close();
  }
}
