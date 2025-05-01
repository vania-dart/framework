import 'dart:convert';
import 'dart:io';
import 'package:mime/mime.dart';
import 'package:string_scanner/string_scanner.dart';
import 'package:vania/src/http/request/request_file.dart';

class RequestFormData {
  final HttpRequest request;

  final RegExp _token = RegExp(r'[^()<>@,;:"\\/[\]?={} \t\x00-\x1F\x7F]+');
  final RegExp _whitespace = RegExp(r'(?:(?:\r\n)?[ \t]+)*');
  final RegExp _quotedString = RegExp(r'"(?:[^"\x00-\x1F\x7F]|\\.)*"');
  final RegExp _quotedPair = RegExp(r'\\(.)');

  final Map<String, dynamic> inputs = <String, dynamic>{};

  RequestFormData({required this.request});

  /// Extract form data from the current request.
  ///
  /// This method is used to parse form data from the current request.
  /// It will extract the form data from the request body and store them in the
  /// [inputs] property.
  ///
  /// The method works by transforming the request body into a list of
  /// [MimeMultipart] objects. Then it will loop through each part and extract the
  /// name and filename from the 'content-disposition' header. If the filename is
  /// not null and not empty, the method will create a [RequestFile] object and
  /// store it in the [inputs] property. If the input name contains '[]', the
  /// method will create a list of [RequestFile] objects and store it in the
  /// [inputs] property. Otherwise, the method will store the string value of the
  /// part in the [inputs] property.
  ///
  /// The method returns the current object.
  Future extractData() async {
    MimeMultipartTransformer transformer = MimeMultipartTransformer(
        request.headers.contentType!.parameters['boundary']!);

    List<MimeMultipart> formData =
        await request.cast<List<int>>().transform(transformer).toList();

    for (MimeMultipart formItem in formData) {
      String partHeaders = formItem.headers['content-disposition']!;
      String? contentType = formItem.headers['content-type'];

      Map<String, String> data = _parseFormDataContentDisposition(partHeaders);
      String? inputName = data['name'];

      if (inputName != null) {
        if (data['filename'] == null || data['filename']!.isEmpty) {
          var value = utf8.decode(await formItem.first);
          if (inputName.contains('[]')) {
            String clearedInputName = inputName.replaceAll('[]', '');
            if (inputs.containsKey(clearedInputName)) {
              if (inputs[clearedInputName] is List) {
                inputs[clearedInputName]
                    .add(int.tryParse(value.toString()) ?? value.toString());
              }
            } else {
              List valueList = [];
              valueList.add(int.tryParse(value.toString()) ?? value.toString());
              inputs[clearedInputName] = valueList;
            }
          } else {
            inputs[inputName] =
                int.tryParse(value.toString()) ?? value.toString();
          }
        } else {
          RequestFile file = RequestFile(
            filename: data['filename'].toString(),
            filetype: contentType.toString(),
            stream: formItem,
          );
          if (inputName.contains('[]')) {
            String clearedInputName = inputName.replaceAll('[]', '');
            if (inputs.containsKey(clearedInputName)) {
              if (inputs[clearedInputName] is List<RequestFile>) {
                inputs[clearedInputName].add(file);
              }
            } else {
              List<RequestFile> files = [];
              files.add(file);
              inputs[clearedInputName] = files;
            }
          } else {
            inputs[inputName] = file;
          }
        }
      }
    }

    return this;
  }

  /// Parses the Content-Disposition header of a form-data part.
  ///
  /// This method takes the header string and uses a `StringScanner` to
  /// extract key-value pairs that represent parameters of the
  /// Content-Disposition header. Keys and values are separated by "="
  /// and multiple parameters are separated by ";".
  ///
  /// Quoted strings are handled correctly by removing surrounding quotes
  /// and unescaping any quoted-pair characters. The resulting parameters
  /// are returned as a map.
  ///
  /// Throws a `FormatException` if the header does not conform to the
  /// expected format.

  Map<String, String> _parseFormDataContentDisposition(String header) {
    StringScanner scanner = StringScanner(header);
    scanner
      ..scan(_whitespace)
      ..expect(_token);

    Map<String, String> params = <String, String>{};

    while (scanner.scan(';')) {
      scanner
        ..scan(_whitespace)
        ..scan(_token);
      String key = scanner.lastMatch![0]!;
      scanner.expect('=');

      String value;
      if (scanner.scan(_token)) {
        value = scanner.lastMatch![0]!;
      } else {
        scanner.expect(_quotedString, name: 'quoted string');
        String string = scanner.lastMatch![0]!;

        value = string
            .substring(1, string.length - 1)
            .replaceAllMapped(_quotedPair, (Match match) => match[1]!);
      }

      scanner.scan(_whitespace);
      params[key] = value;
    }

    scanner.expectDone();
    return params;
  }
}
