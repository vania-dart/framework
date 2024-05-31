import 'dart:io';

import 'package:vania/vania.dart';

import '../../exception/throttle_exception.dart';
import '../throttle_requests.dart';

class Throttle extends Middleware {
  final int maxAttempts;
  final Duration duration;

  Throttle({
    this.maxAttempts = 6,
    this.duration = const Duration(seconds: 60),
  }) {
    throttle = ThrottleRequests(maxAttempts: maxAttempts, duration: duration);
  }

  late ThrottleRequests throttle;

  @override
  Future handle(Request req) async {
    final clientIp = req.ip;
    if (clientIp == null) {
      req.response.statusCode = HttpStatus.internalServerError;
      req.response.write('Error determining client IP');
      await req.response.close();
      return;
    }

    if (!throttle.request(clientIp)) {
      throw ThrottleException(
        message: 'Too Many Requests.',
        code: HttpStatus.tooManyRequests,
      );
    }
    return await next?.handle(req);
  }
}
