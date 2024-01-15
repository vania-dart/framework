


String sanitizeRoutePath(String path) {
    path = path.replaceAll(RegExp(r'/+'), '/');
    return path.replaceAll(RegExp('^\\/+|\\/+\$'), '');
  }