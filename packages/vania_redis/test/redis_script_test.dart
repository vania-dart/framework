import 'dart:io';

import 'package:test/test.dart';
import 'package:vania_redis/vania_redis.dart';

class _RecordingScriptCommands implements ScriptCommands {
  final List<List<Object?>> calls = [];
  Object? nextEvalShaError;
  Object? nextScriptLoadReturn = 'sha-abc';
  Object? nextEvalReturn = 'evaluated';
  Object? nextEvalShaReturn = 'from-cache';

  @override
  Future<dynamic> eval(
    String script, {
    List<String> keys = const [],
    List<dynamic> arguments = const [],
  }) async {
    calls.add(['EVAL', script, keys, arguments]);
    return nextEvalReturn;
  }

  @override
  Future<dynamic> evalSha(
    String sha, {
    List<String> keys = const [],
    List<dynamic> arguments = const [],
  }) async {
    calls.add(['EVALSHA', sha, keys, arguments]);
    final error = nextEvalShaError;
    if (error != null) {
      nextEvalShaError = null;
      throw error;
    }
    return nextEvalShaReturn;
  }

  @override
  Future<String> scriptLoad(String script) async {
    calls.add(['LOAD', script]);
    return nextScriptLoadReturn.toString();
  }

  @override
  Future<List<bool>> scriptExists(List<String> sha1) async {
    calls.add(['EXISTS', sha1]);
    return List<bool>.filled(sha1.length, true);
  }

  @override
  Future<String?> scriptFlush() async {
    calls.add(const ['FLUSH']);
    return 'OK';
  }
}

void main() {
  group('RedisScript', () {
    test('load() caches the SHA on the instance', () async {
      final script = RedisScript('return 1');
      final commands = _RecordingScriptCommands()
        ..nextScriptLoadReturn = 'aa11';

      final sha = await script.load(commands);

      expect(sha, 'aa11');
      expect(script.sha, 'aa11');
      expect(commands.calls.first, ['LOAD', 'return 1']);
    });

    test('eval() uses EVAL when no SHA is cached', () async {
      final script = RedisScript('return 1');
      final commands = _RecordingScriptCommands();

      final result = await script.eval(commands);

      expect(result, 'evaluated');
      expect(commands.calls.first[0], 'EVAL');
    });

    test('eval() uses EVALSHA once loaded', () async {
      final script = RedisScript('return 1');
      final commands = _RecordingScriptCommands()
        ..nextScriptLoadReturn = 'bb22';
      await script.load(commands);
      commands.calls.clear();

      final result = await script.eval(commands, keys: ['k'], arguments: ['v']);

      expect(result, 'from-cache');
      expect(commands.calls.first[0], 'EVALSHA');
      expect(commands.calls.first[1], 'bb22');
    });

    test(
      'eval() falls back to EVAL on NOSCRIPT then repopulates SHA',
      () async {
        final script = RedisScript('return 1');
        final commands = _RecordingScriptCommands()
          ..nextScriptLoadReturn = 'cc33';
        await script.load(commands);
        commands.calls.clear();
        commands.nextEvalShaError = Exception('NOSCRIPT No matching script');
        commands.nextScriptLoadReturn = 'dd44';

        final result = await script.eval(commands);

        expect(result, 'evaluated');
        final kinds = commands.calls.map((c) => c.first).toList();
        expect(kinds, containsAllInOrder(['EVALSHA', 'EVAL']));
        // give the unawaited SCRIPT LOAD a tick.
        await Future<void>.delayed(Duration.zero);
        expect(script.sha, 'dd44');
      },
    );

    test('eval() rethrows non-NOSCRIPT errors from EVALSHA', () async {
      final script = RedisScript('return 1');
      final commands = _RecordingScriptCommands()
        ..nextScriptLoadReturn = 'ee55';
      await script.load(commands);
      commands.nextEvalShaError = Exception('OOM out of memory');

      await expectLater(script.eval(commands), throwsA(isA<Exception>()));
    });

    test('fromFile() reads source and derives a name', () async {
      final tmp = await Directory.systemTemp.createTemp('redis_script_test_');
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final file = File('${tmp.path}/increment.lua');
      await file.writeAsString('return redis.call("INCR", KEYS[1])');

      final script = await RedisScript.fromFile(file.path);

      expect(script.name, 'increment');
      expect(script.source, contains('INCR'));
    });
  });

  group('RedisScriptRepository', () {
    test('register() stores a script under a name', () {
      final repo = RedisScriptRepository();

      final script = repo.register('bump', 'return 1');

      expect(repo.scripts, {'bump': script});
      expect(repo.get('bump'), same(script));
    });

    test('get() throws for unknown names', () {
      final repo = RedisScriptRepository();
      expect(() => repo.get('missing'), throwsA(isA<RedisException>()));
    });

    test('loadDirectory() ignores missing directories', () async {
      final repo = RedisScriptRepository();

      final added = await repo.loadDirectory(
        '/definitely/not/a/real/scripts/path',
      );

      expect(added, isEmpty);
    });

    test('loadDirectory() registers every .lua file', () async {
      final tmp = await Directory.systemTemp.createTemp('redis_scripts_');
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      await File('${tmp.path}/a.lua').writeAsString('return 1');
      await File('${tmp.path}/b.lua').writeAsString('return 2');
      await File('${tmp.path}/skip.txt').writeAsString('return 3');

      final repo = RedisScriptRepository();
      final added = await repo.loadDirectory(tmp.path);

      expect(added..sort(), ['a', 'b']);
      expect(repo.get('a').source, 'return 1');
      expect(repo.get('b').source, 'return 2');
    });

    test(
      'preloadAll() calls SCRIPT LOAD for every registered script',
      () async {
        final repo = RedisScriptRepository()
          ..register('a', 'return 1')
          ..register('b', 'return 2');
        final commands = _RecordingScriptCommands();

        await repo.preloadAll(commands);

        final loaded = commands.calls
            .where((c) => c.first == 'LOAD')
            .map((c) => c[1])
            .toList();
        expect(loaded..sort(), ['return 1', 'return 2']);
      },
    );

    test('run() delegates to the named script', () async {
      final commands = _RecordingScriptCommands()
        ..nextScriptLoadReturn = 'sha-1';
      final repo = RedisScriptRepository()..register('bump', 'return 1');
      await repo.get('bump').load(commands);
      commands.calls.clear();

      await repo.run(commands, 'bump', keys: ['k'], arguments: [1]);

      expect(commands.calls.first[0], 'EVALSHA');
      expect(commands.calls.first[1], 'sha-1');
    });
  });
}
