mixin CanResetPassword {
  String? _passwordResetToken;
  DateTime? _passwordResetExpiresAt;

  String? get passwordResetToken => _passwordResetToken;
  DateTime? get passwordResetExpiresAt => _passwordResetExpiresAt;

  void setResetToken(
    String token, {
    Duration expiresIn = const Duration(hours: 1),
  }) {
    _passwordResetToken = token;
    _passwordResetExpiresAt = DateTime.now().add(expiresIn);
  }

  bool get isResetTokenValid {
    if (_passwordResetToken == null || _passwordResetExpiresAt == null) {
      return false;
    }
    return DateTime.now().isBefore(_passwordResetExpiresAt!);
  }

  void clearResetToken() {
    _passwordResetToken = null;
    _passwordResetExpiresAt = null;
  }
}
