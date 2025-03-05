abstract interface class DatabaseConnection {
  Future<void> connect();
  Future<List<Map<String, dynamic>>> select(String query);
  Future insert(String query);
  Future execute(String query);
  Future<void> close();
}
