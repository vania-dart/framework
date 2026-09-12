import 'dart:io';

import 'package:test/test.dart';
import 'package:vania_cli/vania_cli.dart';

void main() {
  late Directory project;

  setUp(() async {
    project = await Directory.systemTemp.createTemp('vania_cli_stub_');
    await Directory('${project.path}/lib').create();
  });

  tearDown(() => project.delete(recursive: true));

  T at<T extends Command>(T command) => command..workingDirectory = project;

  String read(String relative) =>
      File('${project.path}/$relative').readAsStringSync();

  test(
    'make:controller supports nested paths without leaking placeholders',
    () async {
      final result = await at(
        CreateControllerCommand(),
      ).execute(['admin/PostController']);

      expect(result, ExitCode.success);
      final source = read(
        'lib/app/http/controllers/admin/post_controller.dart',
      );
      expect(source, contains('class PostController extends Controller'));
      expect(source, contains('final PostController postController'));
      expect(source, isNot(contains('ControllerName')));
    },
  );

  test('make:middleware writes a typed handle override', () async {
    final result = await at(CreateMiddlewareCommand()).execute(['Auth']);

    expect(result, ExitCode.success);
    final source = read('lib/app/http/middleware/auth.dart');
    expect(source, contains('Future<void> handle(Request req)'));
  });

  test('make:model preserves the v2 model API', () async {
    final result = await at(CreateModelCommand()).execute(['BlogPost']);

    expect(result, ExitCode.success);
    expect(
      read('lib/app/models/blog_post.dart'),
      contains('class BlogPost extends Model {}'),
    );
  });

  test('refuses overwrite unless --force is present', () async {
    final command = at(CreateControllerCommand());
    await command.execute(['PostController']);
    final path =
        '${project.path}/lib/app/http/controllers/post_controller.dart';
    File(path).writeAsStringSync('custom');

    expect(await command.execute(['PostController']), ExitCode.failure);
    expect(File(path).readAsStringSync(), 'custom');

    expect(
      await command.execute(['PostController', '--force']),
      ExitCode.success,
    );
    expect(File(path).readAsStringSync(), isNot('custom'));
  });

  test('rejects traversal, punctuation and unknown options', () async {
    final command = at(CreateControllerCommand());

    for (final arguments in <List<String>>[
      ['../Escape'],
      ['Bad Name'],
      ['Post', '--unknown'],
    ]) {
      expect(await command.execute(arguments), ExitCode.usage);
    }
  });
}
