import 'package:test/test.dart';
import 'package:vaniaFramework/src/extensions/map_extension.dart';

void main() {
  group('MapExtensions Tests', () {
    test('getParam retrieves a value correctly', () {
      Map<dynamic, dynamic> map = {
        'user': {
          'name': {'first': 'John', 'last': 'Doe'}
        }
      };
      expect(map.getParam('user.name.first'), equals('John'));
    });

    test('getParam returns null for non-existent key', () {
      Map<dynamic, dynamic> map = {
        'user': {
          'name': {'first': 'John', 'last': 'Doe'}
        }
      };
      expect(map.getParam('user.name.middle'), isNull);
    });

    test('removeParam removes the key and returns map', () {
      Map<dynamic, dynamic> map = {
        'user': {
          'name': {'first': 'John', 'last': 'Doe'}
        }
      };
      map.removeParam('user.name.first');
      expect(
          map,
          equals({
            'user': {
              'name': {'last': 'Doe'}
            }
          }));
    });

    test('removeParam does nothing on incorrect path', () {
      Map<dynamic, dynamic> map = {
        'user': {
          'name': {'first': 'John', 'last': 'Doe'}
        }
      };
      map.removeParam('user.age.first');
      expect(
          map,
          equals({
            'user': {
              'name': {'first': 'John', 'last': 'Doe'}
            }
          }));
    });
  });
}
