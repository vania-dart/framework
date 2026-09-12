extension MapExtensions on Map<String, dynamic> {
  Map<dynamic, dynamic> removeParam(String keys) {
    List<String> parts = keys.split('.');
    Map<dynamic, dynamic> data = this;
    for (int i = 0; i < parts.length - 1; i++) {
      if (data[parts[i]] is Map) {
        data = data[parts[i]];
      } else {
        return this;
      }
    }
    data.remove(parts.last);
    return this;
  }

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
