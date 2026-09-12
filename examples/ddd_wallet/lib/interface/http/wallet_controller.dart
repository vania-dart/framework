import 'package:vania/http/controller.dart';
import 'package:vania/http/request.dart';
import 'package:vania/http/response.dart';
import 'package:ddd_wallet/application/wallet_service.dart';
import 'package:ddd_wallet/domain/wallet.dart';
import 'package:ddd_wallet/domain/wallet_exception.dart';
import 'package:ddd_wallet/infrastructure/in_memory_wallet_repository.dart';

/// Composition root: pick the infrastructure, inject it into the
/// application service. This is the only place that knows the concrete
/// repository.
final WalletService _service = WalletService(InMemoryWalletRepository());

/// Thin adapter: translates HTTP in/out and maps domain errors to status
/// codes. No business logic here.
class WalletController extends Controller {
  Future<Response> open(Request req, String id) async {
    return _guard(() => _service.open(id), 201);
  }

  Future<Response> show(Request req, String id) async {
    return _guard(() => _service.balance(id));
  }

  Future<Response> deposit(Request req, String id) async {
    await req.validate({'cents': 'required|numeric'});
    return _guard(() => _service.deposit(id, int.parse(req.input('cents').toString())));
  }

  Future<Response> withdraw(Request req, String id) async {
    await req.validate({'cents': 'required|numeric'});
    return _guard(() => _service.withdraw(id, int.parse(req.input('cents').toString())));
  }

  Response _guard(Wallet Function() action, [int status = 200]) {
    try {
      final wallet = action();
      return Response.json({
        'id': wallet.id,
        'balance': wallet.balance.cents,
      }, status);
    } on WalletException catch (e) {
      final code = e.message.endsWith('not found') ? 404 : 422;
      return Response.json({'message': e.message}, code);
    }
  }
}

final WalletController walletController = WalletController();
