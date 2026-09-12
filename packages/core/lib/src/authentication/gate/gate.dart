import 'package:vania/src/ioc_container.dart';

class Gate {
  Gate.createDefault();

  factory Gate() => IoCContainer().resolveOrDefault<Gate>(Gate.createDefault);

  /// All of the defined abilities.
  final Map<String, Function> _abilities = {};

  /// Define a new ability.
  /// Gate().define('canDeletePost', () {
  ///   return user.id == post.user_id;
  /// });
  void define(String ability, Function callback) {
    _abilities[ability] = callback;
  }

  /// Determine if all of the given abilities should be granted for the current user.
  /// Gate().allows('canDeletePost');
  bool allows(String ability) {
    final gate = _abilities[ability];
    if (gate != null) {
      return gate();
    }
    return false;
  }

  /// Determine if a given ability has been defined.
  bool has(String ability) {
    return _abilities.containsKey(ability);
  }

  /// Determine if any of the given abilities should be denied for the current user.
  bool denies(String ability) {
    return !allows(ability);
  }

  /// Remove a previously defined ability.
  void forget(String ability) {
    _abilities.remove(ability);
  }

  /// Remove every defined ability. Useful for tests that need a clean slate.
  void clear() {
    _abilities.clear();
  }
}
