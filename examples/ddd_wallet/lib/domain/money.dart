import 'package:ddd_wallet/domain/wallet_exception.dart';

/// Value object: an amount of money in whole cents. Immutable, compared by
/// value, and never negative — the invariant lives in the type itself.
class Money {
  final int cents;

  const Money._(this.cents);

  factory Money(int cents) {
    if (cents < 0) {
      throw const WalletException('Money cannot be negative');
    }
    return Money._(cents);
  }

  static const Money zero = Money._(0);

  Money add(Money other) => Money(cents + other.cents);

  Money subtract(Money other) => Money(cents - other.cents);

  bool isLessThan(Money other) => cents < other.cents;

  @override
  bool operator ==(Object other) => other is Money && other.cents == cents;

  @override
  int get hashCode => cents.hashCode;

  @override
  String toString() => (cents / 100).toStringAsFixed(2);
}
