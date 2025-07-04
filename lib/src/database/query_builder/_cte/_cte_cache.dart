class CteCache {
  String? _cachedWithClause;
  Map<String, dynamic>? _cachedBindings;
  int _cteHashCode = 0;
  bool _isDirty = true;

  void markDirty() {
    _isDirty = true;
    _cachedWithClause = null;
    _cachedBindings = null;
  }

  bool needsUpdate(int currentHashCode) {
    return _isDirty || _cteHashCode != currentHashCode;
  }

  void updateCache(
      String withClause, Map<String, dynamic> bindings, int hashCode) {
    _cachedWithClause = withClause;
    _cachedBindings = Map.from(bindings);
    _cteHashCode = hashCode;
    _isDirty = false;
  }

  String? get cachedWithClause => _cachedWithClause;

  Map<String, dynamic>? get cachedBindings =>
      _cachedBindings != null ? Map.from(_cachedBindings!) : null;

  void clear() {
    _cachedWithClause = null;
    _cachedBindings = null;
    _cteHashCode = 0;
    _isDirty = true;
  }
}
