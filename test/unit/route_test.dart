

import 'package:test/test.dart';
import 'package:vania/src/route/route_data.dart';
import 'package:vania/vania.dart';

void main(){
  group('Route Test', () {

    test('get route', () {
      Router.get('/test', () {
        return Response.html('test');
      });
      RouteData data = Router().routes.first;
      expect(data.path, '/test');
      expect(data.method, 'GET');
      expect(data.action, () {
        return Response.html('test');
      });
    });

    
  });
}