import 'package:ddd_wallet/domain/wallet.dart';
import 'package:ddd_wallet/domain/wallet_repository.dart';

/// Infrastructure: a concrete [WalletRepository]. Replace it with a
/// database-backed implementation and nothing in the domain or
/// application layer changes.
class InMemoryWalletRepository implements WalletRepository {
  final Map<String, Wallet> _store = {};

  @override
  Wallet? findById(String id) => _store[id];

  @override
  void save(Wallet wallet) => _store[wallet.id] = wallet;
}
