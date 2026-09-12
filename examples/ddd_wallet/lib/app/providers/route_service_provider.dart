import 'package:vania/service_provider.dart';
import 'package:ddd_wallet/interface/http/wallet_route.dart';

class RouteServiceProvider extends ServiceProvider {
  @override
  Future<void> register() async {}

  @override
  Future<void> boot() async {
    WalletRoute().register();
  }
}
