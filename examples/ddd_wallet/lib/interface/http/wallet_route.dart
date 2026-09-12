import 'package:vania/route.dart';
import 'package:ddd_wallet/interface/http/wallet_controller.dart';

class WalletRoute extends Route {
  @override
  String? get prefix => 'api';

  @override
  void register() {
    super.register();

    Router.post('/wallets/{id}', walletController.open);
    Router.get('/wallets/{id}', walletController.show);
    Router.post('/wallets/{id}/deposit', walletController.deposit);
    Router.post('/wallets/{id}/withdraw', walletController.withdraw);
  }
}
