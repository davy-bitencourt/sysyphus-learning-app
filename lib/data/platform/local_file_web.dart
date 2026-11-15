// The browser has no arbitrary filesystem access. Media is stored in SQLite.
Future<List<int>?> readBytes(String path) async => null;
Future<bool> exists(String path) async => false;
Future<String> saveBytes(List<int> bytes, String extension, String subfolder) async =>
    throw UnsupportedError('Use o armazenamento de mídia do navegador.');
Future<String> persistPicked(String sourcePath, String subfolder) async =>
    throw UnsupportedError('Caminhos locais não existem no navegador.');
Future<void> delete(String path) async {}
Future<void> writeBytes(String path, List<int> bytes) async =>
    throw UnsupportedError('Não é possível gravar neste caminho pelo navegador.');
