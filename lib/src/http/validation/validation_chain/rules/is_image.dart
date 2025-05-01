import 'package:vania/src/http/request/request_file.dart';
import 'package:vania/src/http/validation/validation_chain/export_chain_validation.dart';

class IsImage extends ValidationRule {
  final String args;
  IsImage({required this.args, super.message});

  @override
  bool validate(value, data) {
    if (value is RequestFile) {
      return false;
    }
    if (args.toString().isNotEmpty) {
      extensions = args.toString().split(',');
    }
    if (extensions.contains(value.extension)) {
      return true;
    }
    return false;
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'The $field must be a file';
  }
}

List<String> extensions = <String>[
  'jpg',
  'jpeg',
  'png',
  'gif',
  'bmp',
  'svg',
  'webp',
  'tiff',
  'ico'
];
