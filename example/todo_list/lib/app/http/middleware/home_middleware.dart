import 'package:vania/vania.dart';

class HomeMiddleware extends Middleware {
  @override
  handle(Request req) async {
    next?.handle(req);
  }
}
