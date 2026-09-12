import 'package:ddd_wallet/domain/wallet.dart';

/// The domain owns this contract; the infrastructure layer implements it.
/// Application code depends on this interface, not on any storage detail.
abstract interface class WalletRepository {
  Wallet? findById(String id);
  void save(Wallet wallet);
}
