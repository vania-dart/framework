/// Raised when a domain rule is violated (negative money, overdraft, …).
class WalletException implements Exception {
  final String message;
  const WalletException(this.message);

  @override
  String toString() => 'WalletException: $message';
}
