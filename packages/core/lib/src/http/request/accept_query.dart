import 'dart:io';

/// What may appear unquoted in a Structured Field token (RFC 9651 §3.3.4).
final RegExp _sfToken = RegExp(r"^[A-Za-z*][!#$%&'*+\-.^_`|~0-9A-Za-z:/]*$");

/// [mediaTypes] as an `Accept-Query` value (RFC 10008 §3): a Structured
/// Field list in which a media type that is not a valid token — one
/// starting with a digit, say — is sent as a quoted string.
String acceptQueryHeader(List<String> mediaTypes) => [
  for (final type in mediaTypes)
    _sfToken.hasMatch(type)
        ? type
        : '"${type.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"',
].join(', ');

/// Whether [contentType] is one of [accepted], which may hold `type/*`
/// and `*/*`.
bool acceptsMediaType(List<String> accepted, ContentType contentType) {
  final primary = contentType.primaryType.toLowerCase();
  final sub = contentType.subType.toLowerCase();
  for (final range in accepted) {
    final slash = range.indexOf('/');
    if (slash < 0) continue;
    final rangePrimary = range.substring(0, slash);
    final rangeSub = range.substring(slash + 1);
    if (rangePrimary == '*' && rangeSub == '*') return true;
    if (rangePrimary != primary) continue;
    if (rangeSub == '*' || rangeSub == sub) return true;
  }
  return false;
}
