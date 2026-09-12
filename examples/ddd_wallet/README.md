# DDD Wallet Example

A small **Domain-Driven Design** sample built with the
[Vania](../../packages/core) framework. A wallet you can open, deposit into,
and withdraw from — used to show the DDD layering, not the money math.

## Layers

The dependency rule points inward: outer layers depend on inner ones, never
the reverse.

```
lib/
  domain/                     # the core — pure Dart, no framework
    money.dart                #   value object (immutable, never negative)
    wallet.dart               #   aggregate root (guards its own invariants)
    wallet_repository.dart    #   repository interface (owned by the domain)
    wallet_exception.dart     #   domain error
  application/
    wallet_service.dart       # use-case orchestration (no business rules)
  infrastructure/
    in_memory_wallet_repository.dart  # concrete repository implementation
  interface/http/
    wallet_controller.dart    # HTTP adapter + composition root
    wallet_route.dart         # routes
  app/providers/ , config/    # framework wiring
bin/server.dart
test/                         # domain + application tests
```

### The ideas it demonstrates

- **Value object** — `Money` is immutable, compared by value, and enforces
  "never negative" in its own constructor.
- **Aggregate root** — `Wallet` exposes behaviour (`deposit`, `withdraw`),
  not setters; the balance can never go below zero or change from outside.
- **Repository interface in the domain**, implemented in infrastructure, so
  the application layer depends on an abstraction — swap the in-memory store
  for a database without touching the domain.
- **Application service** orchestrates a use case (load → act → save) and
  holds no rules of its own.
- **Thin HTTP layer** — the controller only maps requests/responses and
  turns domain errors into status codes.

## Endpoints

| Method | Path                          | Description        |
|--------|-------------------------------|--------------------|
| POST   | `/api/wallets/{id}`           | Open a wallet      |
| GET    | `/api/wallets/{id}`           | Show the balance   |
| POST   | `/api/wallets/{id}/deposit`   | Deposit `cents`    |
| POST   | `/api/wallets/{id}/withdraw`  | Withdraw `cents`   |

## Running

```bash
dart pub get
dart run bin/server.dart
```

## Tests

The domain and application layers are pure Dart, so they test without a
server or database:

```bash
dart test
```
