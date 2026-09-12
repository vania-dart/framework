---
sidebar_position: 10
---

# IoC Container

Vania includes a lightweight inversion-of-control (IoC) container for dependency management. It supports factory registration and singleton resolution.

## Registering Services

Use `IoCContainer` to bind an interface or class to a factory function:

```dart
import 'package:vania/vania.dart';

// Register a factory (new instance each time)
IoCContainer().register<EmailService>(() => SmtpEmailService());

// Register a singleton (created once, reused)
IoCContainer().register<CacheService>(
  () => RedisCacheService(),
  singleton: true,
);
```

When `singleton: true` is set, the factory is called immediately and the instance is stored for all future resolutions.

## Resolving Services

```dart
var emailService = IoCContainer().resolve<EmailService>();
var cacheService = IoCContainer().resolve<CacheService>();
```

Each call to `resolve()` returns the singleton instance or calls the factory to create a new one, depending on how the service was registered.

## Using in Service Providers

The most common place to register services is inside a `ServiceProvider`:

```dart
class AppServiceProvider extends ServiceProvider {
  @override
  Future<void> register() async {
    IoCContainer().register<NotificationService>(
      () => PushNotificationService(env('FCM_KEY')),
      singleton: true,
    );

    IoCContainer().register<StorageService>(
      () => S3StorageService(
        bucket: env('AWS_BUCKET'),
        region: env('AWS_REGION'),
      ),
      singleton: true,
    );
  }

  @override
  Future<void> boot() async {}
}
```

## Using in Controllers

Resolve services in your controller methods:

```dart
class OrderController extends Controller {
  Future<Response> store(Request req) async {
    final notifier = IoCContainer().resolve<NotificationService>();
    // ... create order ...
    await notifier.send(userId, 'Order placed');
    return Response.json({'status': 'created'}, 201);
  }
}
```

## Framework-Registered Services

The framework registers a few services automatically:

- `RequestHandler` — the HTTP request pipeline
- `SessionManager` — session handling (singleton)

These are available via `IoCContainer().resolve<T>()` after application initialization.
