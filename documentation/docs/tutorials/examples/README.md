---
sidebar_position: 0
---

# Sample Walkthroughs

The `examples/` folder in the repository holds ten small, self-contained apps. Each one is deliberately narrow: it shows a single idea end to end, with tests, so you can read the whole thing in a sitting and copy the parts you need.

These walkthroughs explain those samples — not just what they do, but *why* they are shaped the way they are. Read them in roughly this order if you are new to Vania: the first few use no external services, so you can run them with nothing but Dart installed.

## No external services

Run these with only the Dart SDK — no database, no Docker.

| Walkthrough | What it teaches |
|-------------|-----------------|
| [Counter](counter.md) | The smallest possible Vania app: routes, a controller, JSON responses. |
| [Todos (modular)](todos.md) | Organising an app by feature, and hiding data access behind a repository. |
| [DDD Wallet](ddd-wallet.md) | Domain-Driven Design layering: value objects, aggregates, and a thin HTTP layer. |
| [GraphQL API](graphql-api.md) | Serving a GraphQL schema with a browser IDE, from one provider. |
| [gRPC Greeter](grpc-greeter.md) | A gRPC service running alongside the HTTP server. |
| [Swagger API](swagger-api.md) | Describing a REST API with OpenAPI and serving interactive docs. |

## Needs a service running

These connect to a real backing service (a database, Redis, or Elasticsearch). Each walkthrough gives you a one-line Docker command to start it.

| Walkthrough | Needs |
|-------------|-------|
| [Basic Authentication](basic-authentication.md) | MySQL — register, login, protected routes, logout with JWT. |
| [Redis Cache](redis-cache.md) | Redis — a page-view counter behind a swappable store. |
| [WebSocket Chat](websocket-chat.md) | Nothing extra — real-time rooms over one WebSocket. |
| [Elasticsearch Search](elasticsearch-search.md) | Elasticsearch — full-text search over indexed documents. |

## A pattern you will see everywhere

Almost every sample separates *logic* from *transport*. The counter lives in a plain `Counter` class, the chat lives in a transport-free `ChatHub`, the money rules live in a `Wallet` aggregate. The HTTP or WebSocket layer is a thin adapter on top.

That split is not ceremony. It is what makes each sample's tests run without a server, a socket, or a database — and it is the single habit that will keep your own Vania apps easy to test as they grow. Watch for it as you read.
