


import 'package:vania/vania.dart';

import '../app/http/controller/home_controller.dart';

class ApiRoute implements Route{
  @override
  void registery() {
    Router.get("/", const HomeController());
  }

}