extension MapExtensions on Map<String, dynamic> {
  /// Removes a parameter from a nested map structure based on a dot-separated key path.
  ///
  /// This method allows removing a value from a deeply nested map using a path described by a string of keys separated by dots.
  ///
  /// **Parameters:**
  /// - [keys]: A string representing the path to the value to remove, separated by dots. For example, 'user.profile.name'.
  ///
  /// **Returns:**
  /// The original map with the specified parameter removed if found. If any part of the path is invalid (not a map or non-existent key), the original map is returned unchanged.
  ///
  /// **Example Usage:**
  /// ```dart
  /// var myMap = {
  ///   'user': {
  ///     'profile': {
  ///       'name': 'John',
  ///       'age': 30
  ///     }
  ///   }
  /// };
  /// myMap.removeParam('user.profile.name');
  /// print(myMap); // Outputs: {user: {profile: {age: 30}}}
  /// myMap.removeParam('user.profile.nonExistentKey'); // Does nothing if key does not exist
  /// print(myMap); // Outputs: {user: {profile: {age: 30}}}
  /// ```
  Map<dynamic, dynamic> removeParam(String keys) {
    List<String> parts = keys.split('.');
    Map<dynamic, dynamic> data = this;
    for (int i = 0; i < parts.length - 1; i++) {
      if (data[parts[i]] is Map) {
        data = data[parts[i]];
      } else {
        return this; // Early exit if path is invalid
      }
    }
    data.remove(parts.last);
    return this;
  }

  /// Retrieves a parameter from a nested map structure based on a dot-separated key path.
  ///
  /// This method facilitates accessing values in a deeply nested map using a path described by a string of keys separated by dots.
  ///
  /// **Parameters:**
  /// - [keys]: A string representing the path to the value, separated by dots. For example, 'user.profile.age'.
  ///
  /// **Returns:**
  /// The value at the specified path if it exists and the path is valid. If the path is broken at any point (not a map or key does not exist), returns `null`.
  ///
  /// **Example Usage:**
  /// ```dart
  /// var myMap = {
  ///   'user': {
  ///     'profile': {
  ///       'name': 'John',
  ///       'age': 30
  ///     }
  ///   }
  /// };
  /// var name = myMap.getParam('user.profile.name');
  /// print(name); // Outputs: John
  /// var salary = myMap.getParam('user.profile.salary'); // Path does not exist
  /// print(salary); // Outputs: null
  /// ```
  dynamic getParam(String keys) {
    List<String> parts = keys.split('.');
    Map<String, dynamic> data = this;
    for (int i = 0; i < parts.length - 1; i++) {
      if (data[parts[i]] is Map) {
        data = data[parts[i]];
      } else {
        return [];
      }
    }
    if (data[parts.last] is List) {
      List<Map<String, dynamic>> list =
          List.castFrom<dynamic, Map<String, dynamic>>(data[parts.last]);
      return list;
    }
    return data[parts.last];
  }
}
