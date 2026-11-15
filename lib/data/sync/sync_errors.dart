class SyncAuthException implements Exception {
  final String message;
  const SyncAuthException([this.message = 'ID incorreto ou relógios dos aparelhos muito diferentes.']);
  @override
  String toString() => message;
}
