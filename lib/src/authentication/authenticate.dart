import 'package:vania/vania.dart';

class Authenticate extends Middleware {
  Model authenticatable;
  Authenticate(this.authenticatable);

  @override
  handle(Request req) async {
    String? token = req.header('authorization');
    await Auth().check(authenticatable, token ?? '');
    next?.handle(req);
  }
}
