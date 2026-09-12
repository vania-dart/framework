---
sidebar_position: 3
---

# Walkthrough: DDD Wallet

**Sample:** `examples/ddd_wallet` · **Needs:** nothing but Dart

The todos sample hid data access behind a repository. This one goes further and applies **Domain-Driven Design**: the business rules live in pure Dart objects that know nothing about HTTP or storage, and everything else — the web layer, the database — sits at the edges depending inward.

The example is a wallet you can open, deposit into, and withdraw from. The money math is trivial on purpose; the point is the *shape*, not the arithmetic.

## The dependency rule

DDD's core idea is one arrow: **outer layers depend on inner layers, never the reverse.**

```
interface/http   →   application   →   domain   ←   infrastructure
(controllers)        (use cases)       (rules)      (storage impl)
```

The domain sits at the centre and imports nothing framework-specific. Everything points at it.

```
lib/
  domain/                     # pure Dart, no framework
    money.dart                #   value object
    wallet.dart               #   aggregate root
    wallet_repository.dart    #   repository interface (owned by the domain)
    wallet_exception.dart     #   domain error
  application/
    wallet_service.dart       # use-case orchestration
  infrastructure/
    in_memory_wallet_repository.dart  # a concrete repository
  interface/http/
    wallet_controller.dart    # HTTP adapter + composition root
    wallet_route.dart
```

## Value object: `Money`

A value object is immutable, compared by value, and enforces its own invariants. `Money` can never be negative — that rule lives inside the type, so an invalid `Money` cannot exist anywhere in the program.

```dart
// lib/domain/money.dart
class Money {
  final int cents;
  const Money._(this.cents);

  factory Money(int cents) {
    if (cents < 0) throw const WalletException('Money cannot be negative');
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
}
```

Because equality is by value, two `Money(500)` objects are equal. Because the constructor guards the invariant, no other code has to remember to check for negatives.

## Aggregate root: `Wallet`

An aggregate root owns its state and only allows changes through its own behaviour. Notice there is **no `setBalance`** — the balance changes only via `deposit` and `withdraw`, and each guards the rules.

```dart
// lib/domain/wallet.dart
class Wallet {
  final String id;
  Money _balance;

  Wallet({required this.id, Money balance = Money.zero}) : _balance = balance;

  Money get balance => _balance;

  void deposit(Money amount) {
    if (amount == Money.zero) throw const WalletException('Deposit must be positive');
    _balance = _balance.add(amount);
  }

  void withdraw(Money amount) {
    if (amount == Money.zero) throw const WalletException('Withdrawal must be positive');
    if (_balance.isLessThan(amount)) throw const WalletException('Insufficient funds');
    _balance = _balance.subtract(amount);
  }
}
```

The balance is a private field. Nothing outside the wallet can push it below zero, because nothing outside the wallet can touch it at all. That is the whole promise of an aggregate: *it protects its own invariants*.

## The repository interface — owned by the domain

The domain declares *what* persistence it needs, not *how* it happens:

```dart
// lib/domain/wallet_repository.dart
abstract interface class WalletRepository {
  Wallet? findById(String id);
  void save(Wallet wallet);
}
```

This interface lives in the domain, but it is implemented out in infrastructure. That inversion is what keeps the arrow pointing inward.

## Application service: orchestrate, don't decide

The service loads an aggregate, calls its behaviour, and saves it. It holds **no rules** — the rules are in `Wallet`.

```dart
// lib/application/wallet_service.dart
class WalletService {
  final WalletRepository _repository;
  WalletService(this._repository);

  Wallet deposit(String id, int cents) {
    final wallet = _require(id);
    wallet.deposit(Money(cents));   // the rule lives in the wallet
    _repository.save(wallet);
    return wallet;
  }

  Wallet _require(String id) {
    final wallet = _repository.findById(id);
    if (wallet == null) throw WalletException('Wallet $id not found');
    return wallet;
  }
}
```

Read → act → save. That is the entire job of an application service.

## Infrastructure: a concrete repository

```dart
// lib/infrastructure/in_memory_wallet_repository.dart
class InMemoryWalletRepository implements WalletRepository {
  final Map<String, Wallet> _store = {};

  @override
  Wallet? findById(String id) => _store[id];
  @override
  void save(Wallet wallet) => _store[wallet.id] = wallet;
}
```

Swap this for a database-backed class and the domain and application layers do not change one line — they only ever saw the interface.

## Interface layer: thin HTTP adapter + composition root

The controller is where the concrete pieces are finally wired together (the "composition root"), and where domain errors become HTTP status codes:

```dart
// lib/interface/http/wallet_controller.dart
final WalletService _service = WalletService(InMemoryWalletRepository());

class WalletController extends Controller {
  Future<Response> deposit(Request req, String id) async {
    await req.validate({'cents': 'required|numeric'});
    return _guard(() => _service.deposit(id, int.parse(req.input('cents').toString())));
  }

  Response _guard(Wallet Function() action, [int status = 200]) {
    try {
      final wallet = action();
      return Response.json({'id': wallet.id, 'balance': wallet.balance.cents}, status);
    } on WalletException catch (e) {
      final code = e.message.endsWith('not found') ? 404 : 422;
      return Response.json({'message': e.message}, code);
    }
  }
}
```

The controller does three things and no more: validate input, call the service, and translate a `WalletException` into a `404` or `422`. All the interesting decisions happened deeper in.

## Why this pays off

Because the domain and application layers depend on nothing but pure Dart, the tests run instantly with no server and no database:

```bash
cd examples/ddd_wallet
dart test
```

- `money.dart` and `wallet.dart` are tested by constructing objects and asserting on behaviour (deposit, overdraft, negatives).
- `wallet_service.dart` is tested by injecting an in-memory repository.

## What to take away

- **Value object** — immutability plus a self-checked invariant (`Money` is never negative).
- **Aggregate root** — expose behaviour, not setters; guard your own rules (`Wallet` never overdraws).
- **Repository interface in the domain**, implemented in infrastructure — the inversion that keeps the dependency arrow pointing inward.
- **Application service** orchestrates; it does not decide.
- **Thin interface layer** maps requests to use cases and errors to status codes.

This is more structure than a small app needs — the counter proves that. Reach for it when the *rules* are the hard part of the problem, not the plumbing. For the conceptual background, see [Domain-Driven Design](../../architecture/ddd.md).
