import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';
import 'package:meta/meta.dart';
import 'package:vania/src/mail/mail.dart';
import 'package:vania/vania.dart';

@immutable
class Mailable implements Mail {
  const Mailable();

  SmtpServer _setupSmtpServer() {
    switch (env<String>('MAIL_MAILER', 'smtp')) {
      case 'gmail':
        return gmail(
          env<String>('MAIL_USERNAME', ''),
          env<String>('MAIL_PASSWORD', ''),
        );
      case 'gmailSaslXoauth2':
        return gmailSaslXoauth2(
          env<String>('MAIL_USERNAME', ''),
          Config().get('mail')['accessToken'],
        );
      case 'gmailRelaySaslXoauth2':
        return gmail(
          env<String>('MAIL_USERNAME', ''),
          env<String>('accessToken', ''),
        );
      case 'hotmail':
        return hotmail(
          env<String>('MAIL_USERNAME', ''),
          env<String>('MAIL_PASSWORD', ''),
        );
      case 'mailgun':
        return mailgun(
          env<String>('MAIL_USERNAME', ''),
          env<String>('MAIL_PASSWORD', ''),
        );
      case 'qq':
        return qq(
          env<String>('MAIL_USERNAME', ''),
          env<String>('MAIL_PASSWORD', ''),
        );
      case 'yahoo':
        return yahoo(
          env<String>('MAIL_USERNAME', ''),
          env<String>('MAIL_PASSWORD', ''),
        );
      case 'yandex':
        return yandex(
          env<String>('MAIL_USERNAME', ''),
          env<String>('MAIL_PASSWORD', ''),
        );
      default:
        return SmtpServer(
          env<String>('MAIL_HOST', ''),
          username: env<String>('MAIL_USERNAME', ''),
          password: env<String>('MAIL_PASSWORD', ''),
          port: env<int>('MAIL_PORT', 465),
          ssl: env<String>('MAIL_ENCRYPTION', 'ssl') == 'ssl',
          ignoreBadCertificate: env<bool>('MAIL_IGNORe_BAD_CERTIFICATE', true),
        );
    }
  }

  Future<void> send() async {
    final message = mailer.Message();

    message.from = envelope().from ??
        Address(
          env<String>('MAIL_FROM_ADDRESS', ''),
          env<String>('MAIL_FROM_NAME', ''),
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
