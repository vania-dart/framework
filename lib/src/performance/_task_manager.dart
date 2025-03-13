import 'dart:async';
import 'dart:isolate';
import '../exception/invalid_argument_exception.dart';

class TaskManager {
  static final TaskManager _instance = TaskManager._internal();
  factory TaskManager() => _instance;
  TaskManager._internal();

  final Map<String, Isolate> _activeIsolates = {};
  final Map<String, DateTime> _isolateStartTimes = {};

  static const Duration maxTaskDuration = Duration(minutes: 5);
  static const int maxConcurrentTasks = 4;

  Future<T> runInIsolate<T>(
    Future<T> Function() task, {
    String? taskId,
    Duration? timeout,
    bool killOnTimeout = true,
  }) async {
    final String nonNullTaskId =
        taskId ?? DateTime.now().millisecondsSinceEpoch.toString();
    final Duration nonNullTimeout = timeout ?? maxTaskDuration;

    if (_activeIsolates.length >= maxConcurrentTasks) {
      throw InvalidArgumentException(
        'Maximum concurrent tasks limit reached ($maxConcurrentTasks)',
      );
    }

    final receivePort = ReceivePort();
    final errorPort = ReceivePort();
    final completer = Completer<T>();

    // Create and store isolate
    final isolate = await Isolate.spawn(
      _isolateWrapper,
      _IsolateMessage(task, receivePort.sendPort),
    );

    _activeIsolates[nonNullTaskId] = isolate;
    _isolateStartTimes[nonNullTaskId] = DateTime.now();

    // Setup timeout
    Timer? timeoutTimer;
    if (nonNullTimeout != Duration.zero) {
      timeoutTimer = Timer(nonNullTimeout, () {
        if (killOnTimeout) {
          _terminateIsolate(nonNullTaskId);
        }
        if (!completer.isCompleted) {
          completer.completeError(
            TimeoutException(
                'Task exceeded timeout of ${nonNullTimeout.inSeconds} seconds'),
          );
        }
      });
    }

    // Listen for results
    receivePort.listen((message) {
      if (message is _IsolateResult<T>) {
        timeoutTimer?.cancel();
        _cleanupIsolate(nonNullTaskId);
        if (message.error != null) {
          completer.completeError(message.error!);
        } else {
          completer.complete(message.result);
        }
      }
    });

    // Listen for errors
    errorPort.listen((message) {
      timeoutTimer?.cancel();
      _cleanupIsolate(nonNullTaskId);
      completer.completeError(message);
    });

    return completer.future;
  }

  static void _isolateWrapper<T>(_IsolateMessage message) async {
    try {
      final result = await message.task();
      message.sendPort.send(_IsolateResult<T>(result: result));
    } catch (e, stackTrace) {
      message.sendPort
          .send(_IsolateResult<T>(error: e, stackTrace: stackTrace));
    }
  }

  void _terminateIsolate(String taskId) {
    final isolate = _activeIsolates[taskId];
    if (isolate != null) {
      isolate.kill();
      _cleanupIsolate(taskId);
    }
  }

  void _cleanupIsolate(String taskId) {
    _activeIsolates.remove(taskId);
    _isolateStartTimes.remove(taskId);
  }

  Map<String, Duration> getRunningTasksDurations() {
    final now = DateTime.now();
    return Map.fromEntries(
      _isolateStartTimes.entries.map(
        (entry) => MapEntry(
          entry.key,
          now.difference(entry.value),
        ),
      ),
    );
  }

  void terminateAllTasks() {
    for (var taskId in _activeIsolates.keys.toList()) {
      _terminateIsolate(taskId);
    }
  }
}

class _IsolateMessage<T> {
  final Future<T> Function() task;
  final SendPort sendPort;

  _IsolateMessage(this.task, this.sendPort);
}

class _IsolateResult<T> {
  final T? result;
  final Object? error;
  final StackTrace? stackTrace;

  _IsolateResult({this.result, this.error, this.stackTrace});
}
