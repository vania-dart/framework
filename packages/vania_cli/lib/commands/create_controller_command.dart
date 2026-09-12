import '../common/recase.dart';
import '../common/stubs.dart';
import 'stub_command.dart';

class CreateControllerCommand extends StubCommand {
  @override
  String get name => 'make:controller';

  @override
  String get description => 'Create a new controller class';

  @override
  String get label => 'Controller';

  @override
  String pathFor(String name) {
    final parts = name.split('/');
    final className = parts.removeLast();
    final directory = parts.isEmpty ? '' : '${parts.join('/')}/';
    return 'lib/app/http/controllers/$directory${className.snakeCase}.dart';
  }

  @override
  String render(String name, List<String> arguments) {
    final className = name.split('/').last;
    return Stubs.controller
        .replaceAll('ControllerName', className.pascalCase)
        .replaceAll('varName', className.camelCase);
  }
}
