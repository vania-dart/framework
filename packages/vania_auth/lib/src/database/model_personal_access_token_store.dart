import 'package:vania/vania.dart' show PersonalAccessTokenStore;

class TokenStoreColumns {
  final String primaryKey;
  final String name;
  final String tokenableId;
  final String token;
  final String createdAt;
  final String? deletedAt;
  final String? expiresAt;
  final String? lastUsedAt;
  final String? revokedAt;

  const TokenStoreColumns({
    this.primaryKey = 'id',
    this.name = 'name',
    this.tokenableId = 'tokenable_id',
    this.token = 'token',
    this.createdAt = 'created_at',
    this.deletedAt = 'deleted_at',
    this.expiresAt = 'expires_at',
    this.lastUsedAt = 'last_used_at',
    this.revokedAt = 'revoked_at',
  });
}

class ModelPersonalAccessTokenStore implements PersonalAccessTokenStore {
  final dynamic model;
  final TokenStoreColumns columns;
  final DateTime Function() now;

  ModelPersonalAccessTokenStore({
    required this.model,
    this.columns = const TokenStoreColumns(),
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  @override
  Future<void> create({
    required String name,
    required dynamic tokenableId,
    required String tokenHash,
    required Duration? expiresIn,
  }) async {
    final createdAt = now();
    await model.query.insert({
      columns.name: name,
      columns.tokenableId: tokenableId,
      columns.token: tokenHash,
      columns.createdAt: createdAt,
      if (columns.expiresAt != null && expiresIn != null)
        columns.expiresAt!: createdAt.add(expiresIn),
    });
  }

  @override
  Future<bool> exists(String tokenHash) async {
    final token = await _activeTokenQuery(
      tokenHash,
    ).first([columns.primaryKey]);
    return token != null;
  }

  @override
  Future<Map<String, dynamic>?> find(String tokenHash) async {
    final token = await _activeTokenQuery(tokenHash).first();
    if (token == null) return null;
    return Map<String, dynamic>.from(token);
  }

  @override
  Future<bool> isRevoked(String tokenHash) async {
    final token = await _activeTokenQuery(tokenHash).first([
      columns.primaryKey,
      if (columns.revokedAt != null) columns.revokedAt!,
    ]);
    if (token == null || columns.revokedAt == null) return false;
    return token[columns.revokedAt] != null;
  }

  @override
  Future<void> markUsed(String tokenHash) async {
    if (columns.lastUsedAt == null) return;
    await model.query.where(columns.token, '=', tokenHash).update({
      columns.lastUsedAt!: now(),
    });
  }

  @override
  Future<void> revoke(String tokenHash) async {
    if (columns.revokedAt == null) return;
    await model.query.where(columns.token, '=', tokenHash).update({
      columns.revokedAt!: now(),
    });
  }

  @override
  Future<void> revokeAll(dynamic userId) async {
    if (columns.revokedAt == null) return;
    await model.query.where(columns.tokenableId, '=', userId).update({
      columns.revokedAt!: now(),
    });
  }

  @override
  Future<void> revokeAllByName(String name) async {
    if (columns.revokedAt == null) return;
    await model.query.where(columns.name, '=', name).update({
      columns.revokedAt!: now(),
    });
  }

  dynamic _activeTokenQuery(String tokenHash) {
    final query = model.query.where(columns.token, '=', tokenHash);
    if (columns.deletedAt != null) {
      return query.whereNull(columns.deletedAt!);
    }
    return query;
  }
}
