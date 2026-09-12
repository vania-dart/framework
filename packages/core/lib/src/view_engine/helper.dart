import 'package:vania/src/http/response/response.dart';
import 'template_engine.dart';

Response view(String view, [Map<String, dynamic>? context]) =>
    Response.html(TemplateEngine().render(view, context));
