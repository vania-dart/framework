import 'package:vaniaFramework/vania_framework.dart';

class IsFile extends ValidationRule {
  final String args;
  IsFile({required this.args, super.message});

  @override
  bool validate(value, data) {
    if (value is! RequestFile && value is! List<RequestFile>) {
      return false;
    }

    if (args.isEmpty) {
      return true;
    }

    List<String> validExtensions = args.split(',');

    bool hasValidExtension(RequestFile file) {
      return validExtensions.contains(file.extension);
    }

    if (value is List<RequestFile>) {
      return value.every(hasValidExtension);
    } else {
      return hasValidExtension(value);
    }
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'The $field must be a file';
  }
}
