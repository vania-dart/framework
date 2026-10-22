import 'dart:async';
import 'package:vania/src/ioc_container.dart';

import '../request/request_scope.dart';
import 'session_manager.dart';

class FlashMessages {
  FlashMessages.createDefault();

  factory FlashMessages() => IoCContainer().resolveOrDefault<FlashMessages>(
    FlashMessages.createDefault,
  );

  static const Object _legacyZoneKey = #vania.template_engine.legacy_state;

  final _FlashState _fallback = _FlashState();

  _FlashState get _state {
    final legacy = Zone.current[_legacyZoneKey];
    if (legacy is _FlashState) return legacy;
    return _fallback;
  }

  /// Validation errors keyed by field name.
  Map<String, dynamic> get errors =>
      currentRequestScope?.sessionErrors ?? _state.errors;

  /// The submitted input, used to repopulate a form after a failed
  /// validation round-trip.
  Map<String, dynamic> get old =>
      currentRequestScope?.formData ?? _state.formData;

  /// Flash messages keyed by name.
  Map<String, dynamic> get messages =>
      currentRequestScope?.flashSessions ?? _state.messages;

  /// The session entry flashed values travel to the next request in.
  static const String sessionKey = '_flash';

  /// Stores a flash message under [key], for this request and the next.
  void flash(String key, dynamic value) {
    messages[key] = value;
    _outgoing()?.messages[key] = value;
  }

  /// Reads a flash message, or null when absent.
  dynamic message(String key) => messages[key];

  /// Records a validation error for [field], for this request and the
  /// next.
  void addError(String field, dynamic message) {
    errors[field] = message;
    _outgoing()?.errors[field] = message;
  }

  /// Merges [entries] into the current errors, for this request and the
  /// next.
  void addErrors(Map<String, dynamic> entries) {
    errors.addAll(entries);
    _outgoing()?.errors.addAll(entries);
  }

  /// Removes all validation errors for the current request.
  void clearErrors() {
    errors.clear();
    _existingOutgoing()?.errors.clear();
  }

  /// Removes every flash message, error and old-input entry.
  ///
  /// Rendering a view calls this once the page has used them, so nothing
  /// it has shown is carried over to the next request.
  void clear() {
    errors.clear();
    old.clear();
    messages.clear();
    _existingOutgoing()?.clear();
  }

  /// What this request has flashed so far, registering its save on first
  /// use. Null outside a request.
  _Outgoing? _outgoing() {
    final scope = currentRequestScope;
    if (scope == null) return null;
    final existing = _existingOutgoing();
    if (existing != null) return existing;
    final created = _Outgoing();
    scope.attributes[_Outgoing] = created;
    scope.beforeResponse(() => created.save(scope));
    return created;
  }

  _Outgoing? _existingOutgoing() {
    final value = currentRequestScope?.attributes[_Outgoing];
    return value is _Outgoing ? value : null;
  }

  /// Hands this request what the previous one flashed, and removes it from
  /// the session: flashed values are shown once.
  static Future<void> restore(
    RequestScope scope,
    SessionManager sessions,
  ) async {
    final flashed = scope.sessionData[sessionKey];
    if (flashed is! Map) return;
    for (final (key, bucket) in [
      ('messages', scope.flashSessions),
      ('errors', scope.sessionErrors),
      ('old', scope.formData),
    ]) {
      final values = flashed[key];
      if (values is Map) bucket.addAll(values.cast<String, dynamic>());
    }
    await sessions.deleteSession(sessionKey);
  }

  /// Runs [body] with its own isolated set of buckets, optionally
  /// pre-seeded.
  ///
  static Future<T> runIsolated<T>({
    required Future<T> Function() body,
    Map<String, dynamic>? errors,
    Map<String, dynamic>? flash,
    Map<String, dynamic>? oldInput,
  }) {
    final state = _FlashState();
    if (errors != null) state.errors.addAll(errors);
    if (flash != null) state.messages.addAll(flash);
    if (oldInput != null) state.formData.addAll(oldInput);
    return runZoned<Future<T>>(body, zoneValues: {_legacyZoneKey: state});
  }
}

class _FlashState {
  final Map<String, dynamic> errors = <String, dynamic>{};
  final Map<String, dynamic> formData = <String, dynamic>{};
  final Map<String, dynamic> messages = <String, dynamic>{};
}

/// What one request flashes for the next.
class _Outgoing {
  final Map<String, dynamic> messages = <String, dynamic>{};
  final Map<String, dynamic> errors = <String, dynamic>{};

  void clear() {
    messages.clear();
    errors.clear();
  }

  Future<void> save(RequestScope scope) async {
    if (messages.isEmpty && errors.isEmpty) return;
    await IoCContainer()
        .resolveOrDefault<SessionManager>(SessionManager.new)
        .setSession(FlashMessages.sessionKey, {
          if (messages.isNotEmpty) 'messages': messages,
          if (errors.isNotEmpty) ...{
            'errors': errors,
            // The form comes back filled in, as submitted.
            'old': _storable(scope.formData),
          },
        });
  }

  /// [input] as it may be kept in the session: no passwords, and nothing
  /// that is not plain data, such as an upload.
  static Map<String, dynamic> _storable(Map<String, dynamic> input) => {
    for (final entry in input.entries)
      if (!entry.key.toLowerCase().contains('password') &&
          _isPlain(entry.value))
        entry.key: entry.value,
  };

  static bool _isPlain(Object? value) =>
      value == null ||
      value is String ||
      value is num ||
      value is bool ||
      (value is List && value.every(_isPlain)) ||
      (value is Map && value.values.every(_isPlain));
}
