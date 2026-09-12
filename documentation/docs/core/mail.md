---
sidebar_position: 13
---

# Mail

Vania provides a mail system for sending transactional emails through SMTP. Emails can use raw content or template-rendered views.

## Configuration

Set mail credentials in `.env`:

```env
MAIL_MAILER=smtp
MAIL_HOST=smtp.mailtrap.io
MAIL_PORT=587
MAIL_ENCRYPTION=tls
MAIL_USERNAME=your_username
MAIL_PASSWORD=your_password
MAIL_FROM_ADDRESS=hello@example.com
MAIL_FROM_NAME=MyApp
```

## Writing a Mailable

Create a class that extends `Mailable`:

```dart
import 'package:vania/mail.dart';

class WelcomeEmail extends Mailable {
  final String userName;

  WelcomeEmail(this.userName);

  @override
  Envelope envelope() {
    return Envelope(
      from: Address('hello@example.com', 'MyApp'),
      to: [Address('user@example.com', userName)],
      subject: 'Welcome to MyApp',
    );
  }

  @override
  Content content() {
    return Content(
      html: '<h1>Welcome, $userName!</h1><p>Thanks for joining.</p>',
    );
  }
}
```

### Using Templates

Render a view template for the email body:

```dart
@override
Content content() {
  return Content(
    view: MailView('emails/welcome', {'name': userName}),
  );
}
```

This renders `views/emails/welcome.html` through the template engine.

### Attachments

```dart
@override
List<Attachment> attachments() {
  return [
    Attachment(
      filename: 'guide.pdf',
      data: guideBytes,
    ),
  ];
}
```

## Sending Mail

```dart
import 'package:vania/mail.dart';

await WelcomeEmail('Alice').send();
```

Or from a controller:

```dart
Future<Response> register(Request req) async {
  // ... create user ...
  await WelcomeEmail(req.input('name') as String).send();
  return Response.json({'message': 'Registered'}, 201);
}
```

## Envelope Options

The `Envelope` class supports:

```dart
Envelope(
  from: Address('noreply@example.com', 'MyApp'),
  to: [Address('user@example.com')],
  cc: [Address('team@example.com')],
  bcc: [Address('archive@example.com')],
  subject: 'Your Order Confirmation',
  replyTo: Address('support@example.com'),
);
```

## Generating a Mailable via CLI

```bash
vania make:mail order_confirmation
```
