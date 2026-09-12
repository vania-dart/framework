---
sidebar_position: 3
---

# Microservices Architecture

A microservices architecture splits your application into independent services, each owning its own data and communicating over the network. Vania supports this through gRPC, REST, and WebSocket packages.

## Directory Structure

Each microservice is a standalone Vania project:

```
services/
├── api-gateway/
│   ├── bin/server.dart
│   ├── lib/
│   │   ├── config/app.dart
│   │   ├── routes/api_routes.dart
│   │   ├── controllers/
│   │   │   └── gateway_controller.dart
│   │   ├── middleware/
│   │   │   ├── auth_middleware.dart
│   │   │   └── rate_limit_middleware.dart
│   │   └── clients/
│   │       ├── user_client.dart
│   │       ├── order_client.dart
│   │       └── notification_client.dart
│   ├── .env
│   └── pubspec.yaml
│
├── user-service/
│   ├── bin/server.dart
│   ├── lib/
│   │   ├── config/app.dart
│   │   ├── controllers/user_controller.dart
│   │   ├── models/user.dart
│   │   ├── grpc/
│   │   │   ├── user_grpc_service.dart
│   │   │   └── protos/user.proto
│   │   ├── routes/api_routes.dart
│   │   └── database/
│   │       └── migrations/
│   ├── .env
│   └── pubspec.yaml
│
├── order-service/
│   ├── bin/server.dart
│   ├── lib/
│   │   ├── config/app.dart
│   │   ├── controllers/order_controller.dart
│   │   ├── models/order.dart
│   │   ├── grpc/
│   │   │   └── order_grpc_service.dart
│   │   ├── events/
│   │   │   └── order_events.dart
│   │   └── database/
│   │       └── migrations/
│   ├── .env
│   └── pubspec.yaml
│
├── notification-service/
│   ├── bin/server.dart
│   ├── lib/
│   │   ├── config/app.dart
│   │   ├── consumers/
│   │   │   └── order_event_consumer.dart
│   │   ├── services/
│   │   │   ├── email_service.dart
│   │   │   └── push_service.dart
│   │   └── websocket/
│   │       └── notification_handler.dart
│   ├── .env
│   └── pubspec.yaml
│
├── shared/
│   ├── protos/                    # Shared protobuf definitions
│   │   ├── user.proto
│   │   ├── order.proto
│   │   └── notification.proto
│   └── lib/
│       ├── events.dart            # Shared event contracts
│       └── dto.dart               # Shared data transfer objects
│
└── docker-compose.yml
```

## Service Communication

### Option A: gRPC (Synchronous)

Ideal for service-to-service calls where you need a response:

```dart
// user-service/lib/grpc/user_grpc_service.dart
class UserGrpcService extends UserServiceBase {
  @override
  Future<UserResponse> getUser(ServiceCall call, GetUserRequest request) async {
    final user = await User().query.findOrFail(request.id);
    return UserResponse()
      ..id = user['id']
      ..name = user['name']
      ..email = user['email'];
  }
}
```

```dart
// api-gateway/lib/clients/user_client.dart
class UserClient {
  late final ClientChannel _channel;
  late final UserServiceClient _client;

  UserClient() {
    _channel = GrpcClientFactory.insecure(
      env('USER_SERVICE_HOST', 'localhost'),
      port: env<int>('USER_SERVICE_PORT', 50051),
    );
    _client = UserServiceClient(_channel);
  }

  Future<UserResponse> getUser(int id) async {
    return await _client.getUser(GetUserRequest()..id = id);
  }
}
```

### Option B: REST (Synchronous)

When gRPC overhead is not justified:

```dart
// api-gateway/lib/clients/order_client.dart
import 'dart:convert';
import 'dart:io';

class OrderClient {
  final String baseUrl;
  OrderClient() : baseUrl = env('ORDER_SERVICE_URL', 'http://localhost:8001');

  Future<Map<String, dynamic>> getOrder(int id) async {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse('$baseUrl/api/orders/$id'));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    return jsonDecode(body);
  }
}
```

### Option C: Redis Pub/Sub (Asynchronous)

For fire-and-forget events between services:

```dart
// order-service: publish events
await Redis().command.publish('order.created', jsonEncode({
  'order_id': order['id'],
  'user_id': order['user_id'],
  'total': order['total'],
}));

// notification-service: subscribe to events
var pubsub = await Redis().pubsub(patterns: ['order.*']);
pubsub.stream.listen((message) {
  if (message.channel == 'order.created') {
    // Send confirmation email, push notification, etc.
  }
});
```

## API Gateway Pattern

The gateway service sits in front and handles:

- Request routing to the correct microservice
- Authentication and authorization
- Rate limiting
- Request/response aggregation

```dart
// api-gateway/lib/controllers/gateway_controller.dart
class GatewayController extends Controller {
  final _userClient = UserClient();
  final _orderClient = OrderClient();

  Future<Response> getUserWithOrders(int userId) async {
    final user = await _userClient.getUser(userId);
    final orders = await _orderClient.getOrdersByUser(userId);

    return Response.json({
      'user': user,
      'orders': orders,
    });
  }
}
```

## Docker Compose

```yaml
version: '3.8'

services:
  api-gateway:
    build: ./services/api-gateway
    ports:
      - "8000:8000"
    environment:
      - USER_SERVICE_HOST=user-service
      - ORDER_SERVICE_HOST=order-service
    depends_on:
      - user-service
      - order-service

  user-service:
    build: ./services/user-service
    ports:
      - "8001:8000"
      - "50051:50051"
    environment:
      - DB_HOST=user-db
    depends_on:
      - user-db

  order-service:
    build: ./services/order-service
    ports:
      - "8002:8000"
      - "50052:50051"
    environment:
      - DB_HOST=order-db
      - REDIS_HOST=redis
    depends_on:
      - order-db
      - redis

  notification-service:
    build: ./services/notification-service
    environment:
      - REDIS_HOST=redis
    depends_on:
      - redis

  user-db:
    image: mysql:8
    environment:
      MYSQL_DATABASE: users
      MYSQL_ROOT_PASSWORD: secret

  order-db:
    image: postgres:16
    environment:
      POSTGRES_DB: orders
      POSTGRES_PASSWORD: secret

  redis:
    image: redis:7-alpine
```

## When to Use This

- Your team is large enough to own separate services independently.
- Different parts of the system have very different scaling needs.
- You need different database technologies for different data (MySQL for users, Elasticsearch for search).
- Deployment independence matters — you want to deploy the order service without touching the user service.

## Key Principles

1. **Each service owns its data.** No shared databases. Services communicate through APIs.
2. **Services are independently deployable.** Each has its own `pubspec.yaml`, `.env`, and Docker image.
3. **Shared contracts live in `shared/`.** Protobuf definitions, event schemas, and DTOs are shared as a library.
4. **Prefer async over sync.** Use pub/sub for events that don't need an immediate response.
5. **The gateway is the only public entry point.** Internal services are not exposed to the internet.
