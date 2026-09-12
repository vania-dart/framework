import 'package:vania/http/controller.dart';
import 'package:vania/http/response.dart';
import 'package:counter/app/counter.dart';

class CounterController extends Controller {
  Future<Response> show() async {
    return Response.json({'value': counter.value});
  }

  Future<Response> increment() async {
    return Response.json({'value': counter.increment()});
  }

  Future<Response> decrement() async {
    return Response.json({'value': counter.decrement()});
  }

  Future<Response> reset() async {
    return Response.json({'value': counter.reset()});
  }
}

final CounterController counterController = CounterController();
