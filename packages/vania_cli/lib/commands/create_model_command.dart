import '../common/recase.dart';
import '../common/stubs.dart';
import 'stub_command.dart';

class CreateModelCommand extends StubCommand {
  @override
  String get name => 'make:model';

  @override
  String get description => 'Create a new model class';

  @override
  String get label => 'Model';

  @override
  String pathFor(String name) => 'lib/app/models/${name.snakeCase}.dart';

  @override
  String render(String name, List<String> arguments) =>
      Stubs.model.replaceAll('ModelName', name.pascalCase);
}
