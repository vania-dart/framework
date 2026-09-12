import 'package:test/test.dart';
import 'package:vania_cli/vania_cli.dart';

void main() {
  test('documents every interactive key and watcher option', () {
    final command = ServeCommand();

    expect(command.help, contains('r   hot reload'));
    expect(command.help, contains('R   restart'));
    expect(command.help, contains('l   list routes'));
    expect(command.help, contains('c   clear'));
    expect(command.help, contains('q   quit'));
    expect(command.help, contains('--host <host>'));
    expect(command.help, contains('--port <port>'));
    expect(command.help, contains('--no-reload'));
    expect(command.help, contains('--no-watch'));
  });
}
