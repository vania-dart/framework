---
sidebar_position: 14
---

# Logging

Vania ships a simple file logger. It appends timestamped lines to a file under `storage/logs/` (`vania.log` by default), tagged with a severity level.

## Usage

There is one method, `Logger.log`. Pass the message, and optionally a level and a file name:

```dart
import 'package:vania/vania.dart';

Logger.log('User logged in: user_42');                     // defaults to INFO
Logger.log('Payment gateway unreachable', type: Logger.ERROR);
Logger.log('Rate limit approaching', type: Logger.WARNING);
Logger.log('Request payload: $payload', type: Logger.DEBUG);
```

The `type` defaults to `Logger.INFO`. Use `fileName:` to split logs into separate files:

```dart
Logger.log('Charged the customer', type: Logger.INFO, fileName: 'payments');
// → storage/logs/payments.log
```

## Severity levels

Levels are string constants on `Logger`, following syslog conventions:

| Constant | Meaning |
|----------|---------|
| `Logger.EMERGENCY` | System is unusable |
| `Logger.ALERT` | Immediate action required |
| `Logger.CRITICAL` | Critical conditions |
| `Logger.ERROR` | Runtime errors |
| `Logger.WARNING` | Unusual but recoverable conditions |
| `Logger.SUCCESS` | A notable success |
| `Logger.NOTICE` | Normal but significant events |
| `Logger.INFO` | General informational messages |
| `Logger.DEBUG` | Detailed debugging information |

## Output format

Each entry is one line, prefixed with a timestamp and the level:

```
[2026-08-30 14:32:15] INFO: User logged in: user_42
[2026-08-30 14:32:16] ERROR: Payment gateway unreachable
```

Files are created on first write, so you do not need to set up the `storage/logs/` directory yourself.

## When to use which level

- **INFO** — user actions, successful operations, startup events.
- **WARNING** — deprecated usage, approaching limits, recoverable problems.
- **ERROR** — caught exceptions, failed external calls, data inconsistencies.
- **DEBUG** — payloads, query details, intermediate values. Keep these out of hot paths in production; every call opens and appends to the file.
