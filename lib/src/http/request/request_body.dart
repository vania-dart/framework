import 'dart:convert';
import 'dart:io';

import 'package:vania/src/http/request/request_form_data.dart';

String _fixJsonString(String jsonString) {
  return jsonString.replaceAllMapped(RegExp(r'("\w+": )(\d+)([\s,}])'),
      (Match match) => '${match[1]}"${match[2]}"${match[3]}');
}

class RequestBody {
  const RequestBody();

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
        return _extractUrlEncodedData(bodyString);
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

  static Map<String, dynamic> _extractUrlEncodedData(String inputString) {
    Map<String, dynamic> resultMap = {};
    List<String> keyValuePairs = inputString.split('&');
    for (String pair in keyValuePairs) {
      List<String> keyValue = pair.split('=');
      if (keyValue.length == 2) {
        resultMap[keyValue[0]] =
            int.tryParse(keyValue[1].toString()) ?? keyValue[1];
      }
    }

    return resultMap;
  }

  // static bool _extractUrlEncodedData(String encodedData) {
  //   List data = encodedData.split("&");

  // }

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
