import 'package:test/test.dart';
import 'package:vania_cli/commands/route_list_command.dart';

void main() {
  const output = '''boot log
__VANIA_ROUTES__
[{"method":"GET","uri":"/users","name":"users.index","middleware":[]},{"method":"POST","uri":"/users","name":"users.store","middleware":["Auth"]}]
''';

  test('extracts the marked route payload from application logs', () {
    final routes = RouteListParser.parse(output);

    expect(routes, hasLength(2));
    expect(routes!.first.uri, '/users');
    expect(routes.last.middleware, ['Auth']);
  });

  test('returns null for malformed or unmarked output', () {
    expect(RouteListParser.parse('[]'), isNull);
    expect(RouteListParser.parse('__VANIA_ROUTES__\nnot-json'), isNull);
  });

  test('filters routes by method, path and name', () {
    final routes = RouteListParser.parse(output)!;
    final filter = RouteFilter(method: 'post', path: '/user', name: 'store');

    expect(routes.where(filter.matches).single.method, 'POST');
  });
}
