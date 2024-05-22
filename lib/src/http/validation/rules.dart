import 'package:vania/src/http/request/request_file.dart';

class Rules {
  /// check field is required
  static bool isRequired(
      Map<String, dynamic> data, dynamic value, String args) {
    if (value == null) {
      return false;
    }
    if (value is List) {
      return value.isNotEmpty;
    }
    return value.toString().isNotEmpty;
  }

  /// check field is email
  static bool isEmail(Map<String, dynamic> data, dynamic value, String args) {
    RegExp emailRegex = RegExp(
        r'^[\w-]+(\.[\w-]+)*@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*(\.[a-zA-Z]{2,})$');
    return emailRegex.hasMatch(value.toString());
  }

  /// check field is string
  static bool isString(Map<String, dynamic> data, dynamic value, String args) {
    return value is String;
  }

  /// check field is number
  static bool isNumeric(Map<String, dynamic> data, dynamic value, String args) {
    try {
      num.parse(value.toString());
      return true;
    } catch (e) {
      return false;
    }
  }

  /// check field is ip address
  static bool isIp(Map<String, dynamic> data, dynamic value, String args) {
    RegExp ipAddressRegex = RegExp(
      r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
    );
    return ipAddressRegex.hasMatch(value.toString());
  }

  /// check field is boolean
  static bool isBoolean(Map<String, dynamic> data, dynamic value, String args) {
    return value is bool;
  }

  /// check field is integer
  static bool isInteger(Map<String, dynamic> data, dynamic value, String args) {
    try {
      int.parse(value.toString());
      return true;
    } catch (e) {
      return false;
    }
  }

  /// check field is double
  static bool isDouble(Map<String, dynamic> data, dynamic value, String args) {
    try {
      double.parse(value.toString());
      return true;
    } catch (e) {
      return false;
    }
  }

  /// check field is array
  static bool isArray(Map<String, dynamic> data, dynamic value, String args) {
    return value is List;
  }

  /// check field is map or json
  static bool isJson(Map<String, dynamic> data, dynamic value, String args) {
    return value is Map;
  }

  /// check field is alphabetic
  static bool isAlpha(Map<String, dynamic> data, dynamic value, String args) {
    RegExp alphabeticRegex = RegExp(r'^[a-zA-Z]+$');
    return alphabeticRegex.hasMatch(value.toString());
  }

  /// check field is only with alphabetic, dash or underscore
  static bool isAlphaDash(
      Map<String, dynamic> data, dynamic value, String args) {
    RegExp alphaDashRegex = RegExp(r'^[a-zA-Z-_]+$');
    return alphaDashRegex.hasMatch(value.toString());
  }

  /// check field is only with alphabetic, number
  static bool isAlphaNumeric(
      Map<String, dynamic> data, dynamic value, String args) {
    RegExp alphaNumericRegex = RegExp(r'^[a-zA-Z0-9]+$');
    return alphaNumericRegex.hasMatch(value.toString());
  }

  /// check field is a date or date time
  static bool isDate(Map<String, dynamic> data, dynamic value, String args) {
    try {
      DateTime? dateTime = DateTime.tryParse(value.toString());
      return dateTime != null;
    } catch (e) {
      return false;
    }
  }

  /// check field is a valid url
  static bool isUrl(Map<String, dynamic> data, dynamic value, String args) {
    try {
      Uri? uri = Uri.tryParse(value);
      return uri != null && uri.hasScheme && uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }

  /// check field is a valid uuid
  static bool isUUID(Map<String, dynamic> data, dynamic value, String args) {
    RegExp uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegex.hasMatch(value.toString());
  }

  /// check field character is given max length
  static bool maxLength(Map<String, dynamic> data, dynamic value, String max) {
    return value.toString().length <= num.parse(max.toString());
  }

  /// check field character is given min length
  static bool minLength(Map<String, dynamic> data, dynamic value, String min) {
    return value.toString().length >= num.parse(min.toString());
  }

  /// check field character is between given length
  static bool lengthBetween(
      Map<String, dynamic> data, dynamic value, String values) {
    List<String> parts = values.toString().split(',');
    num value1 = num.parse(parts[0]);
    num value2 = num.parse(parts[1]);
    value = value.toString().length;
    if (value1 < value2) {
      return value >= value1 && value <= value2;
    }
    return value >= value2 && value <= value1;
  }

  /// check field is between given value
  static bool between(Map<String, dynamic> data, dynamic value, String values) {
    List<String> parts = values.toString().split(',');
    num value1 = num.parse(parts[0]);
    num value2 = num.parse(parts[1]);
    value = num.parse(value.toString());
    if (value1 < value2) {
      return value >= value1 && value <= value2;
    }
    return value >= value2 && value <= value1;
  }

  /// check field is greater than given value
  static bool greaterThan(
      Map<String, dynamic> data, dynamic value, String compare) {
    value = num.parse(value.toString());
    return value > num.parse(compare.toString());
  }

  /// check field is less than given value
  static bool lessThan(
      Map<String, dynamic> data, dynamic value, String compare) {
    value = num.parse(value.toString());
    return value < num.parse(compare.toString());
  }

  /// check field is reach min value
  static bool min(Map<String, dynamic> data, dynamic value, String compare) {
    value = num.parse(value.toString());
    return value >= num.parse(compare.toString());
  }

  /// check field is not over max value
  static bool max(Map<String, dynamic> data, dynamic value, String compare) {
    value = num.parse(value.toString());
    return value <= num.parse(compare.toString());
  }

  /// check field is in given array
  static bool inArray(Map<String, dynamic> data, dynamic value, String arr) {
    List<String> array = arr.toString().split(',');
    return array.contains(value.toString());
  }

  /// check field is not in given array
  static bool notInArray(Map<String, dynamic> data, dynamic value, String arr) {
    List<String> array = arr.toString().split(',');
    return !array.contains(value.toString());
  }

  /// check field start with given text
  static bool startWith(
      Map<String, dynamic> data, dynamic value, String start) {
    return value.toString().startsWith(start.toString());
  }

  /// check field end with given text
  static bool endWith(Map<String, dynamic> data, dynamic value, String end) {
    return value.toString().endsWith(end.toString());
  }

  /// check 2 password are matched
  static bool confirmed(Map<String, dynamic> data, dynamic value, String key) {
    key = key.toString().isEmpty ? 'password_confirmation' : key;
    dynamic confirmValue = data[key];
    return confirmValue == value;
  }

  /// check field is required when condition is matched
  static bool requiredIf(
      Map<String, dynamic> data, dynamic value, String payload) {
    List<String> parts = payload.toString().split(',');
    String secondField = parts[0];
    String secondFieldValueFromRule = parts[1].toString();
    String? secondFieldValueFromRequest = data[secondField].toString();

    /// check only when req value and rule value are same
    if (secondFieldValueFromRule == secondFieldValueFromRequest) {
      return isRequired(data, value, '');
    }
    return true;
  }

  /// check field is required when condition is not matched
  static bool requiredIfNot(
      Map<String, dynamic> data, dynamic value, String payload) {
    List<String> parts = payload.toString().split(',');
    String secondField = parts[0];
    String secondFieldValueFromRule = parts[1].toString();
    String? secondFieldValueFromRequest = data[secondField].toString();

    /// check only when req value and rule value are same
    if (secondFieldValueFromRule != secondFieldValueFromRequest) {
      return isRequired(data, value, '');
    }
    return true;
  }

  /// check field is valid image
  static bool isImage(Map<String, dynamic> data, dynamic value, String args) {
    if (value is! RequestFile) {
      return false;
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
    if (args.toString().isNotEmpty) {
      extensions = args.toString().split(',');
    }
    if (extensions.contains(value.extension)) {
      return true;
    }
    return false;
  }

  /// check field is a file
  /// not a file => false
  /// if added supported extension in validation, check with extension
  /// return true
  static bool isFile(Map<String, dynamic> data, dynamic value, String args) {
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
}
