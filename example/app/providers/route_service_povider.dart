

import 'package:vania/vania.dart';

import '../../route/api.dart';

class RouteServiceProvider extends ServiceProvider{
  @override
  Future<void> boot() {
    throw UnimplementedError();
  }

  @override
  Future<void> register() async {
    ApiRoute().registery();
  }

}