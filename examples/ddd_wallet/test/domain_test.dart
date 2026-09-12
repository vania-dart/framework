import 'package:test/test.dart';
import 'package:ddd_wallet/domain/money.dart';
import 'package:ddd_wallet/domain/wallet.dart';
import 'package:ddd_wallet/domain/wallet_exception.dart';

void main() {
  group('Money', () {
    test('rejects negative amounts', () {
      expect(() => Money(-1), throwsA(isA<WalletException>()));
    });

    test('adds and subtracts by value', () {
      expect(Money(100).add(Money(50)), Money(150));
      expect(Money(100).subtract(Money(40)), Money(60));
    });

    test('equal by value', () {
      expect(Money(100), Money(100));
    });
  });

  group('Wallet aggregate', () {
    test('starts at zero balance', () {
      expect(Wallet(id: 'w1').balance, Money.zero);
    });

    test('deposit increases the balance', () {
      final wallet = Wallet(id: 'w1');
      wallet.deposit(Money(500));
      expect(wallet.balance, Money(500));
    });

    test('withdraw decreases the balance', () {
      final wallet = Wallet(id: 'w1', balance: Money(500));
      wallet.withdraw(Money(200));
      expect(wallet.balance, Money(300));
    });

    test('cannot withdraw more than the balance', () {
      final wallet = Wallet(id: 'w1', balance: Money(100));
      expect(() => wallet.withdraw(Money(200)),
          throwsA(isA<WalletException>()));
      expect(wallet.balance, Money(100));
    });

    test('rejects zero deposits and withdrawals', () {
      final wallet = Wallet(id: 'w1', balance: Money(100));
      expect(() => wallet.deposit(Money.zero),
          throwsA(isA<WalletException>()));
      expect(() => wallet.withdraw(Money.zero),
          throwsA(isA<WalletException>()));
    });
  });
}
