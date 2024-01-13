

import 'dart:io';
import 'dart:typed_data';

class DownloadFile {
  String? fileName;
  ContentType? contentType;
  String? contentDisposition;
  Uint8List? data;
  DownloadFile(
      {this.fileName, this.contentType, this.contentDisposition, this.data});
}