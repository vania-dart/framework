import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as path;
import 'package:vania_cli/common/constants.dart';

String snakeToPascal(String name) {
  return name
      .split("_")
      .map((e) => e[0].toUpperCase() + e.substring(1))
      .toList()
      .join('');
}

String pascalToSnake(String input) {
  if (input.isEmpty) return '';
  StringBuffer result = StringBuffer();
  for (int i = 0; i < input.length; i++) {
    if (i != 0 && input[i] != '_' && input[i].toUpperCase() == input[i]) {
      result.write('_');
    }
    result.write(input[i].toLowerCase());
  }
  return result.toString();
}

String generateRandomKey() {
  final random = Random.secure();
  final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Url.encode(keyBytes);
}

String firstLetterLowerCase(String str) {
  return '${str[0].toLowerCase()}${str.substring(1)}';
}

Future<void> updateDartToolVaniaConfig(
  Map<String, dynamic> config, {
  Directory? workingDirectory,
}) async {
  try {
    final configFile = await getDartToolVaniaConfigFile(
      workingDirectory: workingDirectory,
    );
    if (configFile != null) {
      await configFile.writeAsString(jsonEncode(config));
    }
  } catch (_) {}
}

FutureOr<File?> getDartToolVaniaConfigFile({
  Directory? workingDirectory,
}) async {
  try {
    final root = workingDirectory ?? Directory.current;
    final Directory dartToolDir = Directory('${root.path}/.dart_tool');
    if (dartToolDir.existsSync()) {
      final configFile = File(
        path.join(dartToolDir.path, Constants.vaniaConfigFile),
      );
      if (configFile.existsSync()) {
        return configFile;
      } else {
        await configFile.create(recursive: true);
        return configFile;
      }
    }
  } catch (_) {}

  return null;
}

Future<Map<String, dynamic>?> getDartToolVaniaConfig({
  Directory? workingDirectory,
}) async {
  final configFile = await getDartToolVaniaConfigFile(
    workingDirectory: workingDirectory,
  );
  if (configFile != null) {
    String base = configFile.readAsStringSync();
    try {
      if (base == '') {
        Map<String, dynamic> config = {'lastRun': DateTime.now().toString()};
        configFile.writeAsString(jsonEncode(config));
        return config;
      }
      return jsonDecode(base);
    } catch (_) {}
  }
  return null;
}
