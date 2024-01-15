

import 'package:vania/vania.dart';

class HomeController extends Controller{
  const HomeController();

  Future<Response> index(Request request) async{
    return Response.json({'message':'Hello World!'});
  }
}