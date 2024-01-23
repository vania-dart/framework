import 'dart:io';

import 'package:vania/vania.dart';

class HttpCros {
  HttpCros(HttpRequest req) {
    CORSConfig? cors = Config().get('cros');
    if (cors != null && cors.enabled) {
      Map<String, dynamic> headers = <String, dynamic>{
        HttpHeaders.accessControlAllowOriginHeader: cors.origin,
        HttpHeaders.accessControlAllowMethodsHeader: cors.methods,
        HttpHeaders.accessControlAllowHeadersHeader: cors.headers,
        HttpHeaders.accessControlExposeHeadersHeader: cors.exposeHeaders,
        HttpHeaders.accessControlAllowCredentialsHeader: cors.credentials,
        HttpHeaders.accessControlMaxAgeHeader: cors.maxAge,
      };

      headers.forEach((String key, dynamic value) {
        _setCorsValue(req.response, key, value);
      });
    }
  }

  // set cors in header
  void _setCorsValue(HttpResponse res, String key, dynamic data) {
    if (data == null) {
      return;
    }

    /// when data is list of string, eg. ['GET', 'POST']
    if (data is List<String> && data.isNotEmpty) {
      res.headers.add(key, data.join(','));
      return;
    }

    /// when data is string, eg. 'GET'
    if (data is String && data.isNotEmpty) {
      res.headers.add(key, data);
      return;
    }

    /// when data is other type and has value, just convert to string
    if (data != null) {
      res.headers.add(key, data.toString());
    }
  }
}
