import 'package:ddd_wallet/domain/money.dart';
import 'package:ddd_wallet/domain/wallet.dart';
import 'package:ddd_wallet/domain/wallet_exception.dart';
import 'package:ddd_wallet/domain/wallet_repository.dart';

/// Application service: orchestrates use cases by loading an aggregate,
/// invoking its behaviour, and saving it. It holds no business rules of
/// its own — those live in the domain.
class WalletService {
  final WalletRepository _repository;

  WalletService(this._repository);

  Wallet open(String id) {
    final wallet = Wallet(id: id);
    _repository.save(wallet);
    return wallet;
  }

  Wallet deposit(String id, int cents) {
    final wallet = _require(id);
    wallet.deposit(Money(cents));
    _repository.save(wallet);
    return wallet;
  }

  Wallet withdraw(String id, int cents) {
    final wallet = _require(id);
    wallet.withdraw(Money(cents));
    _repository.save(wallet);
    return wallet;
  }

  Wallet balance(String id) => _require(id);

  Wallet _require(String id) {
    final wallet = _repository.findById(id);
    if (wallet == null) {
      throw WalletException('Wallet $id not found');
    }
    return wallet;
  }
}
