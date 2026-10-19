import '../database_helper.dart';
import '../services/media_storage_service.dart';
import 'sync_engine.dart';
import 'sync_models.dart';

/// Porta de entrada da sincronização para o resto do app.
///
/// Sem [transport] (nenhum servidor/conta configurado) o app funciona
/// normalmente, só offline. Quando houver um servidor, basta atribuir uma
/// implementação de [SyncTransport] aqui depois do login.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  SyncTransport? transport;

  bool get isConfigured => transport != null;

  Future<SyncStatus> status() async => syncStatus(await DatabaseHelper.instance.database);

  Future<void> enable() async => syncEnable(await DatabaseHelper.instance.database);

  Future<void> disable() async => syncDisable(await DatabaseHelper.instance.database);

  Future<SyncReport> syncNow() async {
    final t = transport;
    if (t == null) throw StateError('Nenhum servidor de sincronização configurado.');
    final db = await DatabaseHelper.instance.database;
    final engine = SyncEngine(
      db: db,
      transport: t,
      saveMedia: (bytes, extension, isImage) =>
          MediaStorageService.saveBytes(bytes, extension, isImage: isImage),
    );
    return engine.sync();
  }
}
