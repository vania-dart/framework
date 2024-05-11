import 'package:vania/vania.dart';

class WebRoute implements Route {
  @override
  void register() {
    Router.get("/", () {
      return Response.html(
          '<span>Hello World, welcome to Fullstack development with Vania</span>');
    });
  }
}
