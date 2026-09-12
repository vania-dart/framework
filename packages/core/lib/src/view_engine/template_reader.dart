import 'dart:io';
import 'package:vania/src/ioc_container.dart';

import 'package:vania/env.dart' show env;

/// An interface (abstract class) for reading template files.
abstract class TemplateReader {
  /// Reads the template contents from the given [filePath].
  String read(String filePath);
}

class FileTemplateReader implements TemplateReader {
  FileTemplateReader.createDefault();

  factory FileTemplateReader() => IoCContainer()
      .resolveOrDefault<FileTemplateReader>(FileTemplateReader.createDefault);

  /// Template contents, cached when `APP_DEBUG` is false so repeat
  /// renders skip the disk read and UTF-8 decode. In debug mode files are
  /// always re-read, so template edits show up without a restart.
  final Map<String, String> _cache = <String, String>{};

  /// Testing / hot-reload hook: drop cached contents.
  void invalidateCache() => _cache.clear();

  bool get _debug => env<bool>('APP_DEBUG', false);

  /// Reads the html template from the given [template] path.
  ///
  /// The template path is relative to the `lib/resources/view/` directory.
  /// The template file must end with `.html`.
  ///
  /// Throws a [FileSystemException] if the file does not exist.
  @override
  String read(String template) {
    if (!_debug) {
      final cached = _cache[template];
      if (cached != null) return cached;
    }

    final filePath = 'lib/resources/view/$template.html';
    File file = File(filePath);
    if (!file.existsSync()) {
      file = File('$template.html');
      if (!file.existsSync()) {
        throw FileSystemException('Html template not found', filePath);
      }
    }
    final contents = file.readAsStringSync();
    if (!_debug) _cache[template] = contents;
    return contents;
  }
}
