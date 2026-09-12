import 'dart:async';
import 'package:vania/src/ioc_container.dart';

import '../request/request_scope.dart';

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

  /// Stores a flash message under [key].
  void flash(String key, dynamic value) => messages[key] = value;

  /// Reads a flash message, or null when absent.
  dynamic message(String key) => messages[key];

  /// Records a validation error for [field].
  void addError(String field, dynamic message) => errors[field] = message;

  /// Merges [entries] into the current errors.
  void addErrors(Map<String, dynamic> entries) => errors.addAll(entries);

  /// Removes all validation errors for the current request.
  void clearErrors() => errors.clear();

  /// Removes every flash message, error and old-input entry.
  void clear() {
    errors.clear();
    old.clear();
    messages.clear();
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
