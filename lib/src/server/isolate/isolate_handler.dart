class IsolateHandler {
  final String host;
  final int port;
  final bool shared;
  final bool secure;
  final String? certficate;
  final String? privateKey;
  final String? privateKeyPassword;
  IsolateHandler({
    required this.host,
    required this.port,
    required this.shared,
    this.secure = false,
    this.certficate,
    this.privateKey,
    this.privateKeyPassword,
  });
}
