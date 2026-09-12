import 'dart:async';
import 'dart:io';

import '../command/commands.dart';

/// A Lua script that can be executed against a Redis server.
///
/// Once [load] has been called against a [ScriptCommands] impl the returned
/// SHA1 is cached on this instance, and subsequent calls to [eval] will
/// prefer `EVALSHA <sha>` (cheap — the server already has the script) and
/// fall back to `EVAL <source>` transparently when the server reports
/// `NOSCRIPT` (e.g. after a server restart or `SCRIPT FLUSH`).
class RedisScript {
  RedisScript(this.source, {this.name});

  /// Loads a script from a file on disk. The file is read as UTF-8; the
  /// [name] defaults to the file's basename without the `.lua` extension.
  static Future<RedisScript> fromFile(String path, {String? name}) async {
    final file = File(path);
    final source = await file.readAsString();
    final resolvedName =
        name ?? file.uri.pathSegments.last.replaceFirst(RegExp(r'\.lua$'), '');
    return RedisScript(source, name: resolvedName);
  }

  /// The Lua source of the script.
  final String source;

  /// A human-readable name for logs/errors. Optional; defaults to the file
  /// stem when constructed via [fromFile].
  final String? name;

  String? _sha;

  /// The SHA1 the last successful [load] returned, or `null` if the script
  /// has not been loaded yet.
  String? get sha => _sha;

  /// `SCRIPT LOAD` the script and cache the returned SHA1 on this instance.
  Future<String> load(ScriptCommands commands) async {
    final sha = await commands.scriptLoad(source);
    _sha = sha;
    return sha;
  }

  /// Execute the script. Uses `EVALSHA` when a SHA is cached and falls back
  /// to `EVAL` on `NOSCRIPT`, transparently repopulating the SHA cache.
  ///
  /// A leaner alias — [call] — makes `script(commands, keys: …)` work too.
  Future<dynamic> eval(
    ScriptCommands commands, {
    List<String> keys = const [],
    List<dynamic> arguments = const [],
  }) async {
    final cached = _sha;
    if (cached != null) {
      try {
        return await commands.evalSha(cached, keys: keys, arguments: arguments);
      } catch (e) {
        // Retry with EVAL only when the server has forgotten the script.
        // Any other error is surfaced.
        if (!_isNoScriptError(e)) rethrow;
      }
    }
    final result = await commands.eval(
      source,
      keys: keys,
      arguments: arguments,
    );
    // Best-effort — repopulate the SHA cache so subsequent calls skip EVAL.
    unawaited(_refreshSha(commands));
    return result;
  }

  Future<dynamic> call(
    ScriptCommands commands, {
    List<String> keys = const [],
    List<dynamic> arguments = const [],
  }) => eval(commands, keys: keys, arguments: arguments);

  Future<void> _refreshSha(ScriptCommands commands) async {
    try {
      _sha = await commands.scriptLoad(source);
    } catch (_) {
      // Ignore; the next eval() will EVAL directly again.
    }
  }

  static bool _isNoScriptError(Object error) {
    final message = error.toString();
    return message.contains('NOSCRIPT');
  }
}
