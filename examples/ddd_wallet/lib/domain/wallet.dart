import 'package:ddd_wallet/domain/money.dart';
import 'package:ddd_wallet/domain/wallet_exception.dart';

/// Aggregate root. Guards its own invariants: the balance is always the
/// result of valid deposits and withdrawals, and can never go below zero.
/// Callers change a wallet only through its behaviour, never by setting
/// the balance directly.
class Wallet {
  final String id;
  Money _balance;

  // The field is private so the balance changes only through deposit() /
  // withdraw(); the constructor param is public for a readable call site.
  // ignore: prefer_initializing_formals
  Wallet({required this.id, Money balance = Money.zero}) : _balance = balance;

  Money get balance => _balance;

  void deposit(Money amount) {
    if (amount == Money.zero) {
      throw const WalletException('Deposit must be positive');
    }
    _balance = _balance.add(amount);
  }

  void withdraw(Money amount) {
    if (amount == Money.zero) {
      throw const WalletException('Withdrawal must be positive');
    }
    if (_balance.isLessThan(amount)) {
      throw const WalletException('Insufficient funds');
    }
    _balance = _balance.subtract(amount);
  }
}
