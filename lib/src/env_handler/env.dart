import 'dart:io';

import 'package:vania/src/env_handler/env_interface.dart';
import 'package:vania/src/env_handler/env_loader_interface.dart';

class Env implements IEnv {
  final IEnvLoader envLoader;
  Map<String, String> env = <String, String>{};

  Env({required this.envLoader});

  void load({File? file}) {
    if (env.isEmpty) {
      env = envLoader.loadEnvFile(file: file);
    }
  }

  /// get env value
  /// ```
  /// Evn.get('APP_KEY');
  /// Evn.get('APP_KEY', 'Default Value');
  /// Evn.get<int>('PORT', 3000);
  /// Evn.get<num>('PORT', 3000);
  /// Evn.get<String>('APP_KEY');
  /// ```

  @override
  T get<T>(String key, [dynamic defaultValue]) {
    dynamic value = env[key];
    value ??= Platform.environment[key];
    value ??= defaultValue;
    return _parseValue<T>(value);
  }

  T _parseValue<T>(dynamic value) {
    if (T == int) {
      return int.parse(value.toString()) as T;
    } else if (T == num) {
      return num.parse(value.toString()) as T;
    } else if (T == bool) {
      return bool.parse(value.toString()) as T;
    }
    return value as T;
  }
}
