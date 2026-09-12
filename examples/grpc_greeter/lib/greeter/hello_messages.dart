import 'dart:convert';

/// Minimal protobuf wire encoding for a message with a single string field
/// (field number 1). Hand-written so the example needs no `.proto` codegen;
/// a real project would generate these from a `.proto` file.

List<int> _encodeStringField1(String value) {
  final bytes = utf8.encode(value);
  return [0x0A, ..._writeVarint(bytes.length), ...bytes]; // tag 1, wire type 2
}

String _decodeStringField1(List<int> bytes) {
  var i = 0;
  while (i < bytes.length) {
    final tag = _readVarint(bytes, i);
    i = tag.next;
    final field = tag.value >> 3;
    final wireType = tag.value & 0x07;
    if (field == 1 && wireType == 2) {
      final len = _readVarint(bytes, i);
      i = len.next;
      return utf8.decode(bytes.sublist(i, i + len.value));
    }
    return ''; // unexpected field; nothing else to read for these messages
  }
  return '';
}

class HelloRequest {
  const HelloRequest({this.name = ''});
  final String name;

  List<int> writeToBuffer() => _encodeStringField1(name);
  static HelloRequest fromBuffer(List<int> bytes) =>
      HelloRequest(name: _decodeStringField1(bytes));
}

class HelloResponse {
  const HelloResponse({this.message = ''});
  final String message;

  List<int> writeToBuffer() => _encodeStringField1(message);
  static HelloResponse fromBuffer(List<int> bytes) =>
      HelloResponse(message: _decodeStringField1(bytes));
}

class _Varint {
  const _Varint(this.value, this.next);
  final int value;
  final int next;
}

_Varint _readVarint(List<int> bytes, int start) {
  var result = 0, shift = 0, i = start;
  while (i < bytes.length) {
    final byte = bytes[i++];
    result |= (byte & 0x7f) << shift;
    if ((byte & 0x80) == 0) break;
    shift += 7;
  }
  return _Varint(result, i);
}

List<int> _writeVarint(int value) {
  final out = <int>[];
  var v = value;
  while (v > 0x7f) {
    out.add((v & 0x7f) | 0x80);
    v >>= 7;
  }
  out.add(v);
  return out;
}
