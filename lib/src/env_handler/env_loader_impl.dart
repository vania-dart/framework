import 'dart:io';

import 'package:vania/src/env_handler/env_loader_interface.dart';

/// Implements IEnvLoader to provide a method for loading environment variables from a file.
class EnvLoader implements IEnvLoader {
  /// Loads environment variables from a specified file or from a default '.env' file if none is specified.
  /// @param file An optional file parameter to specify a custom file.
  /// @return Returns a map of environment variables with their corresponding values.
  @override
  Map<String, String> loadEnvFile({File? file}) {
    Map<String, String> data = <String, String>{};
    File envFile = file ?? File('.env');
    if (!envFile.existsSync()) return data;
    String contents = envFile.readAsStringSync();
    List<String> list = contents.split('\n');

    for (String d in list) {
      List<String> keyValue = d.toString().split('=');
      if (keyValue.first.isNotEmpty) {
        data[keyValue.first.trim()] = _getValue(keyValue);
      }
    }
    return data;
  }

  /// Helper method to extract the value from the split elements of a line.
  /// @param elements A list of strings, which are the split parts of a line.
  /// @return Returns the cleaned up value as a single string.
  String _getValue(List<String> elements) {
    if (elements.length > 1) {
      List<String> elementsExceptFirst = elements.sublist(1);
      String value = elementsExceptFirst.join('=');
      return value
          .replaceAll('"', '')
          .replaceAll("'", '')
          .replaceAll('`', '')
          .trim();
    }
    return '';
  }
}
