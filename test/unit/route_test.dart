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
      expect(data.method, 'get');
    });

    test('post route', () {
      Router.post('/post', () {});
      RouteData data = Router().routes.first;
      expect(data.path, '/post');
      expect(data.method, 'post');
    });

    test('delete route', () {
      Router.delete('/delete', () {});
      RouteData data = Router().routes.first;
      expect(data.path, '/delete');
      expect(data.method, 'delete');
    });

    test('put route', () {
      Router.put('/put', () {});
      RouteData data = Router().routes.first;
      expect(data.path, '/put');
      expect(data.method, 'put');
    });

    test('patch route', () {
      Router.patch('/patch', () {});
      RouteData data = Router().routes.first;
      expect(data.path, '/patch');
      expect(data.method, 'patch');
    });

    test('options route', () {
      Router.options('/options', () {});
      RouteData data = Router().routes.first;
      expect(data.path, '/options');
      expect(data.method, 'options');
    });

    test('domain route', () {
      Router.get('/get-with-domain', () {}).domain('{username}.test.com');
      RouteData data = Router().routes.first;
      expect(data.domain, '{username}.test.com');
      expect(data.method, 'get');
    });

    test('group route test', () {
      Router.group(() {
        Router.get('/get', () {});
        Router.post('/post', () {});
        Router.delete('/delete', () {});
        Router.put('/put', () {});
        Router.patch('/patch', () {});
        Router.options('/options', () {});
      });
      List<RouteData> data = Router().routes;

      expect(data[0].path, '/get');
      expect(data[0].method, 'get');

      expect(data[1].path, '/post');
      expect(data[1].method, 'post');

      expect(data[2].path, '/delete');
      expect(data[2].method, 'delete');

      expect(data[3].path, '/put');
      expect(data[3].method, 'put');

      expect(data[4].path, '/patch');
      expect(data[4].method, 'patch');

      expect(data[5].path, '/options');
      expect(data[5].method, 'options');
    });

    tearDownAll(() {
      Router().routes.clear();
    });
  });
}
