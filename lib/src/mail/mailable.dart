import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';
import 'package:meta/meta.dart';
import 'package:vania/src/mail/mail.dart';
import 'package:vania/vania.dart';

@immutable
class Mailable implements Mail {
  const Mailable();

  SmtpServer _setupSmtpServer() {
    switch (Config().get('mail')['driver']) {
      case 'gmail':
        return gmail(
            Config().get('mail')['username'], Config().get('mail')['password']);
      case 'gmailSaslXoauth2':
        return gmailSaslXoauth2(Config().get('mail')['username'],
            Config().get('mail')['accessToken']);
      case 'gmailRelaySaslXoauth2':
        return gmail(Config().get('mail')['username'],
            Config().get('mail')['accessToken']);
      case 'hotmail':
        return hotmail(
            Config().get('mail')['username'], Config().get('mail')['password']);
      case 'mailgun':
        return mailgun(
            Config().get('mail')['username'], Config().get('mail')['password']);
      case 'qq':
        return qq(
            Config().get('mail')['username'], Config().get('mail')['password']);
      case 'yahoo':
        return yahoo(
            Config().get('mail')['username'], Config().get('mail')['password']);
      case 'yandex':
        return yandex(
            Config().get('mail')['username'], Config().get('mail')['password']);
      default:
        return SmtpServer(
          Config().get('mail')['host'] ?? '',
          username: Config().get('mail')['username'] ?? '',
          password: Config().get('mail')['password'] ?? '',
          port: Config().get('mail')['port'],
          ssl: Config().get('mail')['encryption'] == 'ssl',
          ignoreBadCertificate:
              Config().get('mail')['ignoreBadCertificate'] ?? true,
        );
    }
  }

  Future<void> send() async {
    final message = mailer.Message();

    message.from = envelope().from ??
        Address(
          Config().get('mail')['from_address'],
          Config().get('mail')['from_name'],
        );
    message.recipients.addAll(envelope().to);

    if (envelope().cc != null) {
      message.ccRecipients.addAll(envelope().cc!);
    }

    if (envelope().bcc != null) {
      message.ccRecipients.addAll(envelope().bcc!);
    }

    message.subject = envelope().subject;
    message.text = content().text;
    message.html = content().html;

    if (attachments() != null) {
      message.attachments.addAll(attachments()!);
    }

    try {
      await mailer.send(message, _setupSmtpServer());
    } catch (e) {
      print('Failed to send email: $e');
      rethrow;
    }
  }

  @mustBeOverridden
  @override
  List<mailer.Attachment>? attachments() {
    throw UnimplementedError();
  }

  @mustBeOverridden
  @override
  Content content() {
    throw UnimplementedError();
  }

  @mustBeOverridden
  @override
  Envelope envelope() {
    throw UnimplementedError();
  }
}
