import 'package:vania/vania.dart';

class ErrorResponseMiddleware extends Middleware {
  @override
  handle(Request req) async {
    if(req.header('content-type') != 'application/json') {
      abort(400,'Your request is not valid');
    }
    next?.handle(req);
  }
}
