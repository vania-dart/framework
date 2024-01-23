import 'package:test/test.dart';
import 'package:vania/src/route/route_data.dart';
import 'package:vania/vania.dart';

void main() {
  group('Route Test', () {
    setUp(() {
      Router().routes.clear();
    });

    test('get route', () {
      Router.get('/get', () {});
      RouteData data = Router().routes.first;
      expect(data.path, '/get');
      expect(data.method, 'GET');
    });

    test('post route', () {
      Router.post('/post', () {});
      RouteData data = Router().routes.first;
      expect(data.path, '/post');
      expect(data.method, 'POST');
    });

    test('delete route', () {
      Router.delete('/delete', () {});
      RouteData data = Router().routes.first;
      expect(data.path, '/delete');
      expect(data.method, 'DELETE');
    });

    test('put route', () {
      Router.put('/put', () {});
      RouteData data = Router().routes.first;
      expect(data.path, '/put');
      expect(data.method, 'PUT');
    });

    test('patch route', () {
      Router.patch('/patch', () {});
      RouteData data = Router().routes.first;
      expect(data.path, '/patch');
      expect(data.method, 'PATCH');
    });

    test('options route', () {
      Router.options('/options', () {});
      RouteData data = Router().routes.first;
      expect(data.path, '/options');
      expect(data.method, 'OPTIONS');
    });

    test('group route test', () {
      Router.group([
        GroupRouter.get('/get', () {}),
        GroupRouter.post('/post', () {}),
        GroupRouter.delete('/delete', () {}),
        GroupRouter.put('/put', () {}),
        GroupRouter.patch('/patch', () {}),
        GroupRouter.options('/options', () {}),
      ]);
      List<RouteData> data = Router().routes;

      expect(data[0].path, '/get');
      expect(data[0].method, 'GET');

      expect(data[1].path, '/post');
      expect(data[1].method, 'POST');

      expect(data[2].path, '/delete');
      expect(data[2].method, 'DELETE');

      expect(data[3].path, '/put');
      expect(data[3].method, 'PUT');

      expect(data[4].path, '/patch');
      expect(data[4].method, 'PATCH');

      expect(data[5].path, '/options');
      expect(data[5].method, 'OPTIONS');
    });

    tearDownAll(() {
      Router().routes.clear();
    });
  });
}
