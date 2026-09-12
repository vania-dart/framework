---
sidebar_position: 1
---

# Docker Deployment

Vania compiles to a native executable, making Docker deployments lightweight and fast.

## Dockerfile

```dockerfile
# Stage 1: Build
FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart pub get --offline

# Run migrations (optional - can also be done separately)
# RUN dart run lib/database/migrations/migrate.dart

# Compile to native executable
RUN dart compile exe bin/server.dart -o bin/server

# Stage 2: Runtime
FROM scratch

COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/server
COPY --from=build /app/.env /app/.env
COPY --from=build /app/public/ /app/public/
COPY --from=build /app/storage/ /app/storage/

WORKDIR /app
EXPOSE 8000

CMD ["bin/server"]
```

The `scratch` base image contains only your binary and its runtime dependencies — no OS, no Dart SDK, no package manager. The result is a minimal container (typically 10–30 MB).

## docker-compose.yml

```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "8000:8000"
    environment:
      - APP_HOST=0.0.0.0
      - APP_PORT=8000
      - DB_HOST=db
      - DB_PORT=3306
      - DB_DATABASE=my_app
      - DB_USERNAME=root
      - DB_PASSWORD=secret
      - REDIS_HOST=redis
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    volumes:
      - app-storage:/app/storage

  db:
    image: mysql:8
    environment:
      MYSQL_ROOT_PASSWORD: secret
      MYSQL_DATABASE: my_app
    ports:
      - "3306:3306"
    volumes:
      - db-data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 5s
      timeout: 3s
      retries: 10

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

volumes:
  db-data:
  app-storage:
```

## Build and Run

```bash
docker compose up --build
```

Your application is available at `http://localhost:8000`.

## Running Migrations

Run migrations as a one-off command:

```bash
docker compose exec app dart run lib/database/migrations/migrate.dart --force
```

`--force` is required here because the container sets `APP_ENV=production`, where
the runner refuses to migrate by default — see
[Migrations](../database/migrations.md#protected-environments).

Or include migration in the Dockerfile build stage (uncomment the migration line).

## Environment Variables

In production, pass environment variables through Docker rather than relying on the `.env` file:

```yaml
environment:
  - APP_KEY=your-production-key-here
  - APP_ENV=production
  - APP_DEBUG=false
  - DB_HOST=your-rds-endpoint.amazonaws.com
  - DB_PASSWORD=${DB_PASSWORD}  # from host environment
```

## Production Considerations

- Set `APP_DEBUG=false` in production to hide error details.
- Use a strong, unique `APP_KEY` (at least 32 characters).
- Put the app behind a reverse proxy (nginx, Caddy) for TLS termination.
- Use connection pooling (`DB_POOL=true`) under load.
- Mount `storage/` as a persistent volume so file uploads and sessions survive container restarts.
- Set `APP_HOST=0.0.0.0` to listen on all interfaces inside the container.
