import 'dart:io';

import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:meta/meta.dart';
import 'package:vania/src/mail/content.dart';
import 'package:vania/src/mail/envelope.dart';
import 'package:vania/src/mail/mail.dart';

import 'package:vania/src/utils/helper.dart' show env;
import 'package:vania/src/view_engine/template_engine.dart';

import 'mail_view.dart';

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
          env<String>('MAIL_ACCESS_TOKEN', ''),
        );
      case 'gmailRelaySaslXoauth2':
        return gmail(
          env<String>('MAIL_USERNAME', ''),
          env<String>('MAIL_ACCESS_TOKEN', ''),
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
          ssl: env<bool>('MAIL_ENCRYPTION', true),
          ignoreBadCertificate: env<bool>('MAIL_IGNORE_BAD_CERTIFICATE', true),
        );
    }
  }

  Future<mailer.SendReport> send() async {
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
    MailView? mailView = view();
    Content? contentData = content();

    if (mailView != null) {
      message.html = TemplateEngine().render(
        mailView.view,
        mailView.data ?? {},
      );
    } else if (contentData != null) {
      message.text = contentData.text;
      message.html = contentData.html;
    }

    print(message.text);
    print(message.html);

    if (attachments() != null) {
      message.attachments.addAll(attachments()!);
    }
    try {
      mailer.SendReport sendReport = await mailer.send(
        message,
        _setupSmtpServer(),
      );
      return sendReport;
    } on SmtpMessageValidationException catch (e) {
      stderr.writeln('Failed to send email:${e.problems.map((error) => {
            message: error.msg,
            error: error.code
          }).toList()}');
      throw Exception(e.problems
          .map((error) => {message: error.msg, error: error.code})
          .toList());
    } catch (e) {
      stderr.writeln('Failed to send email: $e');
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
  MailView? view() {
    throw UnimplementedError();
  }

  @mustBeOverridden
  @override
  Content? content() {
    throw UnimplementedError();
  }

  @mustBeOverridden
  @override
  Envelope envelope() {
    throw UnimplementedError();
  }
}
