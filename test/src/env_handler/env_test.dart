import 'package:mockito/annotations.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:vania/src/env_handler/env.dart';
import 'package:vania/src/env_handler/env_loader_interface.dart';

import 'env_test.mocks.dart';

@GenerateMocks([IEnvLoader])
void main() {
  group('Env', () {
    test('loads environment variables only once', () {
      var mockEnvLoader = MockIEnvLoader();
      when(mockEnvLoader.loadEnvFile(file: anyNamed('file')))
          .thenReturn({'APP_KEY': '123456'});

      var env = Env(envLoader: mockEnvLoader);
      env.load(); // First load
      env.load(); // Attempt to load again

      // Verify that the environment variables are loaded only once
      verify(mockEnvLoader.loadEnvFile(file: null)).called(1);
      expect(env.get<String>('APP_KEY'), '123456');
    });

    test('retrieves environment variable as correct type', () {
      var mockEnvLoader = MockIEnvLoader();
      when(mockEnvLoader.loadEnvFile())
          .thenReturn({'PORT': '8080', 'DEBUG_MODE': 'true'});

      var env = Env(envLoader: mockEnvLoader);
      env.load();

      // Test fetching and type casting
      expect(env.get<int>('PORT'), 8080);
      expect(env.get<bool>('DEBUG_MODE'), true);
    });

    test('returns default value if key not found', () {
      var mockEnvLoader = MockIEnvLoader();
      when(mockEnvLoader.loadEnvFile()).thenReturn({});

      var env = Env(envLoader: mockEnvLoader);
      env.load();

      // Test default values
      expect(env.get<String>('NON_EXISTENT_KEY', 'default'), 'default');
      expect(env.get<int>('NON_EXISTENT_KEY', 42), 42);
      expect(env.get<double>('NON_EXISTENT_KEY', 42.2), 42.2);
      expect(env.get<num>('NON_EXISTENT_KEY', 1.4), 1.4);
      expect(env.get<bool>('NON_EXISTENT_KEY', false), false);
    });
  });
}
