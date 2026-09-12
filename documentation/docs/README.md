---
sidebar_position: 0
slug: /
title: Introduction
---

# Vania Framework Documentation

**Vania** is a server-side framework for Dart, built for developers who want an expressive, batteries-included backend with the performance and type safety of Dart. It covers the full spectrum of backend development: routing, ORM, migrations, authentication, real-time communication, caching, mail, and more.

Vania follows a modular architecture. The core package ships everything you need for a production API server. Optional packages extend it with database drivers, Redis, Elasticsearch, GraphQL, gRPC, Swagger, and WebSockets — install only what your project requires.

---

## Table of Contents

### Getting Started
- [Installation & Setup](getting-started/installation.md)
- [Configuration](getting-started/configuration.md)
- [Directory Structure](getting-started/directory-structure.md)

### Core Framework
- [Routing](core/routing.md)
- [Controllers](core/controllers.md)
- [Middleware](core/middleware.md)
- [Requests](core/requests.md)
- [Responses](core/responses.md)
- [Validation](core/validation.md)
- [Views & Templates](core/views-templates.md)
- [Sessions](core/sessions.md)
- [Service Providers](core/service-providers.md)
- [IoC Container](core/ioc-container.md)
- [Caching](core/caching.md)
- [Storage](core/storage.md)
- [Mail](core/mail.md)
- [Logging](core/logging.md)
- [Error Handling](core/error-handling.md)

### Database & ORM
- [Getting Started with Database](database/getting-started.md)
- [Query Builder](database/query-builder.md)
- [Models](database/models.md)
- [Relationships](database/relationships.md)
- [Migrations](database/migrations.md)
- [Seeders & Factories](database/seeders.md)

### Packages
- [Authentication (vania_auth)](packages/auth.md)
- [MySQL Driver (vania_mysql)](packages/mysql.md)
- [PostgreSQL Driver (vania_postgresql)](packages/postgresql.md)
- [MongoDB Driver (vania_mongodb)](packages/mongodb.md)
- [Redis (vania_redis)](packages/redis.md)
- [Elasticsearch (vania_elasticsearch)](packages/elasticsearch.md)
- [GraphQL (vania_graphql)](packages/graphql.md)
- [gRPC (vania_grpc)](packages/grpc.md)
- [Swagger / OpenAPI (vania_swagger)](packages/swagger.md)
- [WebSocket (vania_websocket)](packages/websocket.md)
- [CLI (vania_cli)](packages/cli.md)

### Project Architecture
- [Modular Architecture](architecture/modular.md)
- [Domain-Driven Design (DDD)](architecture/ddd.md)
- [Microservices](architecture/microservices.md)
- [Test-Driven Development (TDD)](architecture/tdd.md)

### Tutorials
- [Build a Blog API](tutorials/blog-api.md)
- [Build a Task Manager](tutorials/task-manager.md)
- [Build an E-Commerce API](tutorials/e-commerce.md)

### Sample Walkthroughs
Guided tours of the runnable apps in the `examples/` folder — start here if you learn best by reading working code.
- [Overview](tutorials/examples/README.md)
- [Counter](tutorials/examples/counter.md) — the smallest Vania app
- [Todos (modular)](tutorials/examples/todos.md) — feature folders and repositories
- [DDD Wallet](tutorials/examples/ddd-wallet.md) — Domain-Driven Design layering
- [Basic Authentication](tutorials/examples/basic-authentication.md) — JWT register/login/logout
- [Redis Cache](tutorials/examples/redis-cache.md) — a counter behind a swappable store
- [WebSocket Chat](tutorials/examples/websocket-chat.md) — real-time rooms and presence
- [GraphQL API](tutorials/examples/graphql-api.md) — schema, resolvers, and GraphiQL
- [gRPC Greeter](tutorials/examples/grpc-greeter.md) — a gRPC service beside the HTTP server
- [Swagger API](tutorials/examples/swagger-api.md) — OpenAPI docs for a REST API
- [Elasticsearch Search](tutorials/examples/elasticsearch-search.md) — full-text search

### Deployment
- [Docker](deployment/docker.md)

---

## Requirements

- Dart SDK `>=3.9.0 <4.0.0`
- A database driver package if using the ORM (MySQL, PostgreSQL, or MongoDB)

## Quick Start

```bash
# Install the CLI
dart pub global activate vania_cli

# Create a new project
vania create my_app

# Navigate and run
cd my_app
vania serve
```

Your server is now running at `http://localhost:8000`.

## Package Overview

| Package | Description | Version |
|---------|-------------|---------|
| `vania` | Core framework | 2.0.0 |
| `vania_auth` | JWT authentication, guards, gates, personal access tokens | 1.0.0 |
| `vania_mysql` | MySQL database driver | 1.0.0 |
| `vania_postgresql` | PostgreSQL database driver | 1.0.0 |
| `vania_mongodb` | MongoDB database driver | 1.0.0 |
| `vania_redis` | Redis cache driver, pub/sub, Lua scripting | 1.0.0 |
| `vania_elasticsearch` | Elasticsearch client with query builder | 1.0.0 |
| `vania_graphql` | GraphQL server with subscriptions | 1.0.0 |
| `vania_grpc` | gRPC server and client | 1.0.0 |
| `vania_swagger` | OpenAPI 3.0 documentation and Swagger UI | 1.0.0 |
| `vania_websocket` | WebSocket channels, presence, and broadcasting | 1.0.0 |
| `vania_cli` | CLI for scaffolding, serving, and migrations | 1.0.0 |

## Links

- Website: [vdart.dev](https://vdart.dev)
- GitHub: [github.com/vania-dart/framework](https://github.com/vania-dart/framework)
