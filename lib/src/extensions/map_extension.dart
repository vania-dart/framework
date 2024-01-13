extension MapExtensions on Map<dynamic, dynamic> {

  Map<String, dynamic> removeParam(String keys) {
    dynamic value = this;
    List<String> parts = keys.split('.');
    List<String> k = parts.sublist(0, parts.length - 1);

    Map<String, dynamic> data = value;
    for (String i in k) {
      data = data[i];
    }
    data.remove(parts.last);
    return value;
  }

  dynamic getParam(String keys) {
    dynamic value = this;
    List<String> parts = keys.split('.');
    List<String> k = parts.sublist(0, parts.length - 1);

    Map<dynamic, dynamic> data = value;
    for (String i in k) {
      if (data[i] is List) {
        return data[i];
      }
      data = data[i];
    }
    return data[parts.last];
  }
}

