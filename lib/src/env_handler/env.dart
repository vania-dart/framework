import 'dart:io';

import 'package:vania/src/env_handler/env_interface.dart';
import 'package:vania/src/env_handler/env_loader_interface.dart';

/// A class that implements the IEnv interface to handle environment configurations.
/// It utilizes an IEnvLoader to load environment variables from a file.
class Env implements IEnv {
  /// A reference to an environment loader that loads the environment variables.
  final IEnvLoader envLoader;
  Map<String, String> env = <String, String>{};

  Env({required this.envLoader});

  /// Loads environment variables from a file. If no file is provided,
  /// a default `.env` file is used. This method only loads the environment variables
  /// if they have not already been loaded.
  ///
  /// Example:
  /// ```dart
  /// var loader = EnvLoader();
  /// var env = Env(envLoader: loader);
  /// env.load(file: File('config/.env'));
  /// ```
  ///
  ///
  void load({File? file}) {
    if (env.isEmpty) {
      env = envLoader.loadEnvFile(file: file);
    }
  }

  /// Retrieves the environment value associated with the given key.
  /// If the key is not found, it returns the provided default value.
  /// The method supports returning values as different types.
  ///
  /// Examples:
  /// ```dart
  /// var appKey = env.get<String>('APP_KEY'); 
  /// var port = env.get<int>('PORT', 3000);
  /// var debugMode = env.get<bool>('DEBUG_MODE', false);
  /// ```
  ///
  /// @param key The environment variable key to retrieve.
  /// @param defaultValue The default value to return if the key is not found.
  /// @return The value of the environment variable, cast to the type specified.
  @override
  T get<T>(String key, [dynamic defaultValue = '']) {
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
