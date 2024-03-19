import 'package:mailer/mailer.dart';

import 'content.dart';
import 'envelope.dart';

abstract class Mail {
  const Mail();
  Content content();
  Envelope envelope();
  List<Attachment>? attachments();
}
