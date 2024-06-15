import 'package:vania/src/route/route_data.dart';
import 'package:vania/vania.dart';

class ControllerHandler {
  void create({
    required RouteData route,
    required Request request,
  }) async {
    List<dynamic> positionalArguments = [];

    if (route.params != null) {
      positionalArguments = route.params!.values
          .map((param) => int.tryParse(param) ?? param)
          .toList();
    }

    if (route.hasRequest) {
      positionalArguments.insert(0, request);
    }

    Response response = await Function.apply(
      route.action,
      positionalArguments,
      {},
    );
    response.makeResponse(request.response);
  }
}
