/// A tiny YAML emitter that covers what OpenAPI 3.1 needs — maps, lists,
/// scalars (String / num / bool / null). No anchors, no flow style, no
/// custom tags. Keys are emitted as unquoted identifiers when safe,
/// otherwise as double-quoted strings.
///
/// The output is stable — key order is preserved from the source map.
String encodeYaml(Object? value) {
  final buffer = StringBuffer();
  _emit(buffer, value, 0);
  return buffer.toString();
}

void _emit(StringBuffer out, Object? value, int indent) {
  if (value is Map) {
    if (value.isEmpty) {
      out.write('{}\n');
      return;
    }
    var first = true;
    value.forEach((key, v) {
      if (first) {
        first = false;
      } else {
        out.write(' ' * indent);
      }
      out
        ..write(_key(key.toString()))
        ..write(':');
      if (v is Map || v is List) {
        if ((v is Map && v.isEmpty) || (v is List && v.isEmpty)) {
          out.write(' ');
          _emit(out, v, indent + 2);
        } else {
          out.write('\n');
          out.write(' ' * (indent + 2));
          _emit(out, v, indent + 2);
        }
      } else {
        out
          ..write(' ')
          ..write(_scalar(v))
          ..write('\n');
      }
    });
    return;
  }

  if (value is List) {
    if (value.isEmpty) {
      out.write('[]\n');
      return;
    }
    var first = true;
    for (final item in value) {
      if (first) {
        first = false;
      } else {
        out.write(' ' * indent);
      }
      out.write('- ');
      if (item is Map || item is List) {
        if ((item is Map && item.isEmpty) || (item is List && item.isEmpty)) {
          _emit(out, item, indent + 2);
        } else {
          _emit(out, item, indent + 2);
        }
      } else {
        out
          ..write(_scalar(item))
          ..write('\n');
      }
    }
    return;
  }

  out
    ..write(_scalar(value))
    ..write('\n');
}

String _key(String key) {
  if (RegExp(r'^[A-Za-z_][A-Za-z0-9_\-]*$').hasMatch(key)) return key;
  return _quoted(key);
}

String _scalar(Object? value) {
  if (value == null) return 'null';
  if (value is bool) return value ? 'true' : 'false';
  if (value is num) return value.toString();
  final s = value.toString();
  if (s.isEmpty) return '""';
  if (s == 'true' || s == 'false' || s == 'null' || s == '~') return _quoted(s);
  if (num.tryParse(s) != null) return _quoted(s);
  if (RegExp(r'[:{}\[\],&\*#?|<>=!%@`\n\t]').hasMatch(s) ||
      s.startsWith(' ') ||
      s.endsWith(' ') ||
      s.startsWith('-') ||
      s.startsWith('?')) {
    return _quoted(s);
  }
  return s;
}

String _quoted(String s) {
  final escaped = s
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n');
  return '"$escaped"';
}
