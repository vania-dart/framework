import '../common/recase.dart';
import '../common/stubs.dart';
import 'stub_command.dart';

class CreateMailCommand extends StubCommand {
  @override
  String get name => 'make:mail';

  @override
  String get description => 'Create a new mailable class';

  @override
  String get label => 'Mailable';

  @override
  String pathFor(String name) => 'lib/app/mail/${name.snakeCase}.dart';

  @override
  String render(String name, List<String> arguments) =>
      Stubs.mail.replaceAll('MailableName', name.pascalCase);
}
