import 'dart:async';
import 'dart:io';

import '../command/commands.dart';
import '../exception.dart';
import 'redis_script.dart';

/// A registry of [RedisScript]s keyed by name.
///
/// Typical use is to point the repository at a directory (e.g.
/// `resources/redis-scripts/`) at boot time. Every `*.lua` file in that
/// directory becomes a script — its filename (without `.lua`) is the name —
/// and each script's SHA1 is preloaded via `SCRIPT LOAD` so that subsequent
/// calls to [run] use `EVALSHA`.
///
/// Scripts can also be registered programmatically via [register], which is
/// convenient for tests and one-off scripts declared inline in Dart source.
class RedisScriptRepository {
  RedisScriptRepository();

  final Map<String, RedisScript> _scripts = <String, RedisScript>{};

  /// The scripts currently registered, keyed by name.
  Map<String, RedisScript> get scripts => Map.unmodifiable(_scripts);

  /// Register a script under [name]. Overwrites any prior entry with the
  /// same name.
  RedisScript register(String name, String source) {
    final script = RedisScript(source, name: name);
    _scripts[name] = script;
    return script;
  }

  /// Scan [directory] for `.lua` files and register each one. Returns the
  /// list of names that were added. Missing directories are ignored so the
  /// caller can wire an optional path without a guard.
  ///
  /// The scan is shallow by default. Set [recursive] to walk sub-directories;
  /// in that case a script named `foo/bar.lua` becomes `foo.bar`.
  Future<List<String>> loadDirectory(
    String directory, {
    bool recursive = false,
  }) async {
    final dir = Directory(directory);
    if (!await dir.exists()) return const <String>[];
    final added = <String>[];
    await for (final entity in dir.list(recursive: recursive)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.lua')) continue;
      final relative = entity.path.substring(dir.path.length + 1);
      final name = relative
          .replaceFirst(RegExp(r'\.lua$'), '')
          .replaceAll(Platform.pathSeparator, '.');
      final source = await entity.readAsString();
      _scripts[name] = RedisScript(source, name: name);
      added.add(name);
    }
    return added;
  }

  /// Call `SCRIPT LOAD` for every registered script against [commands],
  /// caching the returned SHA on each [RedisScript]. Any load error aborts
  /// the batch and is rethrown; scripts loaded before the failure keep
  /// their SHA cache.
  Future<void> preloadAll(ScriptCommands commands) async {
    for (final script in _scripts.values) {
      await script.load(commands);
    }
  }

  /// Look up a script by [name]. Throws [RedisException] when unknown.
  RedisScript get(String name) {
    final script = _scripts[name];
    if (script == null) {
      throw RedisException('Redis script "$name" is not registered');
    }
    return script;
  }

  /// Execute the script named [name] against [commands]. Convenience wrapper
  /// over `get(name).eval(commands, …)`.
  Future<dynamic> run(
    ScriptCommands commands,
    String name, {
    List<String> keys = const [],
    List<dynamic> arguments = const [],
  }) => get(name).eval(commands, keys: keys, arguments: arguments);

  /// Remove all registered scripts. Only the repository is cleared; the
  /// server-side script cache is left intact. Use `commands.scriptFlush()`
  /// to also clear the server side.
  void clear() => _scripts.clear();
}
