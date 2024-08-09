import 'dart:io';
import 'package:mockito/annotations.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:vania/src/env_handler/env_loader_impl.dart';

import 'env_loader_test.mocks.dart';



@GenerateMocks([File,])
void main() {
  group('EnvLoader', () {
    test('should return empty map if .env file does not exist', () {
      var mockFile = MockFile();
      when(mockFile.existsSync()).thenReturn(false);
      var loader = EnvLoader();
      expect(loader.loadEnvFile(file: mockFile), isEmpty);
    });

    test('should load environment variables from file', () {
      var mockFile = MockFile();
      when(mockFile.existsSync()).thenReturn(true);
      when(mockFile.readAsStringSync()).thenReturn('KEY=value\nKEY2=value2');
      var loader = EnvLoader();
      var result = loader.loadEnvFile(file: mockFile);
      expect(result, containsPair('KEY', 'value'));
      expect(result, containsPair('KEY2', 'value2'));
    });

    test('should correctly handle values with equals sign', () {
      var mockFile = MockFile();
      when(mockFile.existsSync()).thenReturn(true);
      when(mockFile.readAsStringSync()).thenReturn('KEY="value1=value2"');
      var loader = EnvLoader();
      var result = loader.loadEnvFile(file: mockFile);
      expect(result, containsPair('KEY', 'value1=value2'));
    });
  });
}
