---
sidebar_position: 9
---

# Service Providers

Service providers are the central place to configure and bootstrap application services. Every major feature — routes, database, cache, auth, WebSocket — is wired through a provider.

## How Providers Work

During application startup, Vania iterates the `providers` list in your `config/app.dart`:

1. **Register phase** — all providers' `register()` methods run first. Use this to bind services into the container, register drivers, or set up configuration.
2. **Boot phase** — after all registrations complete, all providers' `boot()` methods run. Use this for logic that depends on other services being available (connecting to databases, setting up routes, etc.).

## Writing a Service Provider

Extend the `ServiceProvider` abstract class:

```dart
import 'package:vania/vania.dart';
import 'package:vania/service_provider.dart';

class PaymentServiceProvider extends ServiceProvider {
  @override
  Future<void> register() async {
    // Bind services, register drivers, set config
    IoCContainer().register<PaymentGateway>(
      () => StripeGateway(env('STRIPE_KEY')),
      singleton: true,
    );
  }

  @override
  Future<void> boot() async {
    // Run logic after all providers have registered
    final gateway = IoCContainer().resolve<PaymentGateway>();
    await gateway.initialize();
  }
}
```

## Registering a Provider

Add your provider to the `providers` list in `lib/config/app.dart`:

```dart
Map<String, dynamic> config = {
  // ...
  'providers': [
    RouteServiceProvider(),
    DatabaseServiceProvider(),
    PaymentServiceProvider(),
  ],
};
```

Providers execute in the order listed.

## The Route Service Provider

Every Vania app has a `RouteServiceProvider` that registers all route classes. Do this in `boot()`, so it runs after every provider's `register()` has completed:

```dart
class RouteServiceProvider extends ServiceProvider {
  @override
  Future<void> register() async {}

  @override
  Future<void> boot() async {
    ApiRoute().register();
    // ...register any other route classes here
  }
}
```

## Built-in Providers

| Provider | Package | Purpose |
|----------|---------|---------|
| `DatabaseServiceProvider` | `vania` (core) | Connects to database, registers ORM validation rules |
| `AuthServiceProvider` | `vania_auth` | Installs the user resolver, registers auth services |
| `MySqlDriverServiceProvider` | `vania_mysql` | Registers the MySQL driver with the connection factory |
| `PostgreSqlDriverServiceProvider` | `vania_postgresql` | Registers the PostgreSQL driver |
| `MongoDBDriverServiceProvider` | `vania_mongodb` | Registers the MongoDB driver |
| `RedisServiceProvider` | `vania_redis` | Sets up Redis connections and cache driver |
| `ElasticsearchServiceProvider` | `vania_elasticsearch` | Initializes the Elasticsearch client |
| `GraphQLServiceProvider` | `vania_graphql` | Registers GraphQL schema and routes |
| `GrpcServiceProvider` | `vania_grpc` | Starts the gRPC server alongside HTTP |
| `SwaggerServiceProvider` | `vania_swagger` | Generates OpenAPI docs and serves Swagger UI |
| `WebSocketServiceProvider` | `vania_websocket` | Wires WebSocket upgrade handling |

## Generating a Provider via CLI

```bash
vania make:provider payment
```

This creates `lib/app/providers/payment_service_provider.dart` with the register/boot skeleton.
