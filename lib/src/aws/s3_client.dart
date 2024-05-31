import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:vania/src/extensions/date_time_aws_format.dart';
import 'package:vania/src/utils/helper.dart';

class S3Client {
  static final S3Client _singleton = S3Client._internal();
  factory S3Client() => _singleton;
  S3Client._internal();

  final String _region = env<String>('STORAGE_S3_REGION', '');
  final String _bucket = env<String>('STORAGE_S3_BUCKET', '');
  final String _secretKey = env<String>('STORAGE_S3_SECRET_KEY', '');
  final String _accessKey = env<String>('STORAGE_S3_ACCESS_KEY', '');

  Uri buildUri(String key) {
    return Uri.https('$_bucket.s3.$_region.amazonaws.com', '/$key');
  }

  Uint8List _hmacSha256(Uint8List key, String data) {
    var hmac = Hmac(sha256, key);
    return Uint8List.fromList(hmac.convert(utf8.encode(data)).bytes);
  }

  Uint8List _getSignatureKey(
      String key, String date, String regionName, String serviceName) {
    var kDate = _hmacSha256(Uint8List.fromList(utf8.encode('AWS4$key')), date);
    var kRegion = _hmacSha256(kDate, regionName);
    var kService = _hmacSha256(kRegion, serviceName);
    var kSigning = _hmacSha256(kService, 'aws4_request');
    return kSigning;
  }

  Map<String, String> generateS3Headers(
    String method,
    String key, {
    String? hash,
  }) {
    final algorithm = 'AWS4-HMAC-SHA256';
    final service = 's3';
    final dateTime = DateTime.now().toUtc().toAwsFormat();
    final date = dateTime.substring(0, 8).toString();
    final scope = '$date/$_region/$service/aws4_request';

    final signedHeaders = 'host;x-amz-content-sha256;x-amz-date';
    hash ??= sha256.convert(utf8.encode('')).toString();
    final canonicalRequest = [
      method,
      '/$key',
      '',
      'host:$_bucket.s3.$_region.amazonaws.com',
      'x-amz-content-sha256:$hash',
      'x-amz-date:$dateTime',
      '',
      signedHeaders,
      hash
    ].join('\n');

    final stringToSign = [
      algorithm,
      dateTime,
      scope,
      sha256.convert(utf8.encode(canonicalRequest)).toString()
    ].join('\n');

    final signingKey = _getSignatureKey(_secretKey, date, _region, service);
    final signature = _hmacSha256(signingKey, stringToSign)
        .map((e) => e.toRadixString(16).padLeft(2, '0'))
        .join();

    final authorizationHeader = [
      '$algorithm Credential=$_accessKey/$scope',
      'SignedHeaders=$signedHeaders',
      'Signature=$signature'
    ].join(', ');

    return {
      'Authorization': authorizationHeader,
      'x-amz-content-sha256': hash,
      'x-amz-date': dateTime,
    };
  }
}
