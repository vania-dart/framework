import 'package:test/test.dart';
import 'package:ddd_wallet/application/wallet_service.dart';
import 'package:ddd_wallet/domain/money.dart';
import 'package:ddd_wallet/domain/wallet_exception.dart';
import 'package:ddd_wallet/infrastructure/in_memory_wallet_repository.dart';

void main() {
  group('WalletService', () {
    late WalletService service;

    setUp(() {
      service = WalletService(InMemoryWalletRepository());
    });

    test('open creates a wallet with zero balance', () {
      final wallet = service.open('w1');
      expect(wallet.balance, Money.zero);
    });

    test('deposit then withdraw persists across calls', () {
      service.open('w1');
      service.deposit('w1', 1000);
      service.withdraw('w1', 400);
      expect(service.balance('w1').balance, Money(600));
    });

    test('operating on an unknown wallet fails', () {
      expect(() => service.deposit('missing', 100),
          throwsA(isA<WalletException>()));
    });

    test('overdraft is rejected and leaves the balance intact', () {
      service.open('w1');
      service.deposit('w1', 100);
      expect(() => service.withdraw('w1', 500),
          throwsA(isA<WalletException>()));
      expect(service.balance('w1').balance, Money(100));
    });
  });
}
