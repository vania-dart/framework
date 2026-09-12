/// Source templates used by the simple `make:` commands.
abstract final class Stubs {
  static const String controller = '''
import 'package:vania/http/controller.dart';
import 'package:vania/http/request.dart';
import 'package:vania/http/response.dart';

class ControllerName extends Controller {
  Future<Response> index() async {
    return Response.json({'message': 'Hello World'});
  }

  Future<Response> create() async => Response.json({});
  Future<Response> store(Request request) async => Response.json({});
  Future<Response> show(int id) async => Response.json({});
  Future<Response> edit(int id) async => Response.json({});
  Future<Response> update(Request request, int id) async => Response.json({});
  Future<Response> destroy(int id) async => Response.json({});
}

final ControllerName varName = ControllerName();
''';

  static const String middleware = '''
import 'package:vania/http/middleware.dart';
import 'package:vania/http/request.dart';

class MiddlewareName extends Middleware {
  @override
  Future<void> handle(Request req) async {}
}
''';

  static const String model = '''
import 'package:vania/orm/model.dart';

class ModelName extends Model {}
''';

  static const String mail = '''
import 'package:vania/mail.dart';

class MailableName extends Mailable {
  const MailableName({
    required this.to,
    required this.text,
    required this.subject,
  });

  final String to;
  final String text;
  final String subject;

  @override
  List<Attachment>? attachments() => null;

  @override
  Content content() => Content(text: text);

  @override
  Envelope envelope() => Envelope(
        from: Address('from@example.com', 'From Name'),
        to: [Address(to)],
        subject: subject,
      );
}
''';

  static const String provider = '''
import 'package:vania/service_provider.dart';

class ServiceProviderName extends ServiceProvider {
  @override
  Future<void> register() async {}

  @override
  Future<void> boot() async {}
}
''';

  static const String seeder = '''
import 'package:vania/database.dart';
FactoryImport
class SeederName extends Seeder {
  @override
  Future<void> run() async {
SeederBody
  }
}
''';

  static const String factory = '''
import 'package:vania/database.dart' show SeederFactory;

class FactoryName extends SeederFactory {
  @override
  Map<String, dynamic> definition() => {};
}
''';

  static const String databaseSeeder = '''
import 'package:vania/database.dart' show SeederRunner;

import '../../config/database.dart';

void main(List<String> args) async {
  await SeederRunner().setup(
    database: database,
    seeders: [
    ],
    args: args,
  );
}
''';
}
