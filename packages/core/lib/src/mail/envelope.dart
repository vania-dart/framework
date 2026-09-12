import 'package:mailer/mailer.dart';

class Envelope {
  ///The address sending the message.
  final Address? from;

  /// The recipients of the message.
  final List<Address> to;

  /// The recipients receiving a copy of the message.
  final List<dynamic>? cc;

  /// The recipients receiving a blind copy of the message.
  final List<dynamic>? bcc;

  /// The subject of the message.
  final String subject;

  Envelope({
    this.from,
    required this.to,
    required this.subject,
    this.cc,
    this.bcc,
  });
}
