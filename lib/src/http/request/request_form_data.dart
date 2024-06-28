import 'dart:io';
import 'package:mime/mime.dart';
import 'package:string_scanner/string_scanner.dart';
import 'package:vania/vania.dart';

class RequestFormData {
  final HttpRequest request;

  final RegExp _token = RegExp(r'[^()<>@,;:"\\/[\]?={} \t\x00-\x1F\x7F]+');
  final RegExp _whitespace = RegExp(r'(?:(?:\r\n)?[ \t]+)*');
  final RegExp _quotedString = RegExp(r'"(?:[^"\x00-\x1F\x7F]|\\.)*"');
  final RegExp _quotedPair = RegExp(r'\\(.)');

  final Map<String, dynamic> inputs = <String, dynamic>{};

  RequestFormData({required this.request});

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
          var value = String.fromCharCodes(await formItem.first);
          inputs[inputName] =
              int.tryParse(value.toString()) ?? value.toString();
        } else {
          RequestFile file = RequestFile(
            filename: data['filename'].toString(),
            filetype: contentType.toString(),
            stream: formItem,
          );
          if (inputName.contains('[]')) {
            List<RequestFile> files = [];
            files.add(file);
            String clearedInputName = inputName.replaceAll('[]', '');
            if (inputs.containsKey(clearedInputName)) {
              if (inputs[clearedInputName] is List<RequestFile>) {
                inputs[clearedInputName].add(file);
              }
            } else {
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
