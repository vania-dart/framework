import 'package:mailer/mailer.dart';

import 'content.dart';
import 'envelope.dart';
import 'mail_view.dart';

abstract class Mail {
  const Mail();
  Content? content();
  MailView? view();
  Envelope envelope();
  List<Attachment>? attachments();
}
