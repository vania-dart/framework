import '../common/recase.dart';
import '../common/stubs.dart';
import 'stub_command.dart';

class CreateServiceProviderCommand extends StubCommand {
  @override
  String get name => 'make:provider';

  @override
  String get description => 'Create a new service provider class';

  @override
  String get label => 'Service provider';

  @override
  String pathFor(String name) => 'lib/app/providers/${name.snakeCase}.dart';

  @override
  String render(String name, List<String> arguments) =>
      Stubs.provider.replaceAll('ServiceProviderName', name.pascalCase);
}
