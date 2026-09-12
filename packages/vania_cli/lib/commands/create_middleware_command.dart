import '../common/recase.dart';
import '../common/stubs.dart';
import 'stub_command.dart';

class CreateMiddlewareCommand extends StubCommand {
  @override
  String get name => 'make:middleware';

  @override
  String get description => 'Create a new middleware class';

  @override
  String get label => 'Middleware';

  @override
  String pathFor(String name) =>
      'lib/app/http/middleware/${name.snakeCase}.dart';

  @override
  String render(String name, List<String> arguments) =>
      Stubs.middleware.replaceAll('MiddlewareName', name.pascalCase);
}
