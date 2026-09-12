/// The connection contract every driver must satisfy.
abstract interface class DatabaseConnection {
  Future<void> connect();
  Future<List<Map<String, dynamic>>> select(
    String query, [
    Map<String, dynamic> bindings = const {},
  ]);
  Future<dynamic> insert(
    String query, [
    Map<String, dynamic> bindings = const {},
  ]);
  Future<bool> execute(
    String query, [
    Map<String, dynamic> bindings = const {},
  ]);
  Future<T> transaction<T>(Future<T> Function() action);

  Future<void> close();
}
