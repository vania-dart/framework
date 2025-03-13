import 'dart:convert';
import 'dart:io';

import 'package:vania/src/http/request/request_form_data.dart';

/// Adjusts the JSON string by ensuring numbers are correctly formatted without
/// trailing spaces. This function uses a regular expression to find
/// occurrences of key-value pairs where the value is a number, and removes
/// any space between the number and subsequent characters like commas or
/// closing braces. It helps in fixing formatting issues in JSON strings
/// where numbers might be followed by unintended spaces.

String _fixJsonString(String jsonString) {
  return jsonString.replaceAllMapped(
      RegExp(r'("\w+":)\s*(\d+|\d+\.\d+)([\s,}])'),
      (Match match) => '${match[1]}${match[2]}${match[3]}');
}

class RequestBody {
  const RequestBody();

  /// Extracts the request body from an `HttpRequest` and returns it as a
  /// `Map<String, dynamic>`. The function handles JSON, URL-encoded, and
  /// form-data content types. If the content type is JSON, it decodes the
  /// request body into a map. If the content type is URL-encoded, it splits
  /// the query string into a map. For form-data content type, it processes
  /// the request using `RequestFormData`. If the content type is not
  /// supported or an error occurs during parsing, an empty map is returned.
  ///
  /// - Parameter request: The `HttpRequest` from which to extract the body.
  ///
  /// - Returns: A `Future` that resolves to a `Map<String, dynamic>`
  ///   representing the request body.

  static Future<Map<String, dynamic>> extractBody(
      {required HttpRequest request}) async {
    if (isJson(request.headers.contentType)) {
      String bodyString = await utf8.decoder.bind(request).join();
      try {
        return jsonDecode(_fixJsonString(bodyString));
      } catch (err) {
        return <String, dynamic>{};
      }
    }

    if (isUrlencoded(request.headers.contentType)) {
      try {
        String bodyString = await utf8.decoder.bind(request).join();
        return Uri.splitQueryString(bodyString);
      } catch (err) {
        return <String, dynamic>{};
      }
    }

    if (isFormData(request.headers.contentType)) {
      RequestFormData formData = RequestFormData(request: request);
      await formData.extractData();
      return formData.inputs;
    }

    return <String, dynamic>{};
  }

  static bool isUrlencoded(ContentType? contentType) {
    return contentType?.mimeType.toLowerCase().contains('urlencoded') == true;
  }

  static bool isFormData(ContentType? contentType) {
    return contentType?.mimeType.toLowerCase().contains('form-data') == true;
  }

  /// http request data is json
  static bool isJson(ContentType? contentType) {
    return contentType.toString().toLowerCase().contains('json') == true;
  }
}
