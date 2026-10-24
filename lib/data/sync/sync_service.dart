import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../database_helper.dart';
import '../services/media_storage_service.dart';
import 'sync_auth.dart';
import 'sync_discovery.dart';
import 'sync_engine.dart';
import 'sync_http_server.dart';
import 'sync_http_transport.dart';
import 'sync_models.dart';
import 'sync_store.dart';

enum SyncRole { none, host, client }

Future<String> _getMeta(Database db, String key) async {
  final rows = await db.rawQuery('SELECT value FROM sync_meta WHERE key = ?', [key]);
  return rows.isEmpty ? '' : ((rows.first['value'] as String?) ?? '');
}

Future<void> _setMeta(Database db, String key, String value) async {
  await db.rawInsert('INSERT OR REPLACE INTO sync_meta (key, value) VALUES (?, ?)', [key, value]);
}

/// Porta de entrada da sincronização para o resto do app.
///
/// Conta = só um ID secreto (sem e-mail). Papéis:
///  - host: este aparelho guarda a cópia central e responde na rede local
///    (normalmente o PC; o app precisa estar aberto para os outros sincronizarem);
///  - client: este aparelho sincroniza com o host.
///
/// Para a internet no futuro, basta outra implementação de [SyncTransport]
/// atribuída a [transport]; o motor e as telas não mudam.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  SyncTransport? transport;
  SyncRole role = SyncRole.none;
  String? accountId;
  String? hostAddress;
  int hostPort = kSyncPort;

  /// Preenchido quando este aparelho é host mas o servidor não subiu.
  String? hostError;

  SyncHttpServer? _server;
  SqliteSyncStore? _store;

  bool get hasAccount => accountId != null && accountId!.isNotEmpty;
  bool get isConfigured => transport != null;
  bool get isHosting => _server?.isRunning ?? false;
  String? get discoveryError => _server?.discoveryError;
  String get accountIdFormatted => formatAccountId(accountId ?? '');

  Future<Database> get _db => DatabaseHelper.instance.database;

  /// Chame no main(), depois de abrir o banco: retoma a conta e o servidor.
  Future<void> init() async {
    try {
      final db = await _db;
      final id = await _getMeta(db, 'account_id');
      if (id.isEmpty) return;
      accountId = id;

      final roleText = await _getMeta(db, 'role');
      if (roleText == 'host') {
        role = SyncRole.host;
        await _startHosting(db, id);
      } else if (roleText == 'client') {
        final host = await _getMeta(db, 'host_address');
        if (host.isEmpty) return;
        role = SyncRole.client;
        hostAddress = host;
        hostPort = int.tryParse(await _getMeta(db, 'host_port')) ?? kSyncPort;
        transport = HttpSyncTransport(host: host, port: hostPort, accountId: id);
      }
    } catch (e) {
      hostError = '$e';
      debugPrint('Erro ao iniciar a sincronização: $e');
    }
  }

  Future<SqliteSyncStore> _newStore(Database db) async {
    final docs = await getApplicationDocumentsDirectory();
    return SqliteSyncStore(db: db, blobDir: Directory(p.join(docs.path, 'sysyphus_sync_blobs')));
  }

  Future<void> _startHosting(Database db, String id) async {
    final store = await _newStore(db);
    await store.open();
    final server = SyncHttpServer(transport: store, accountId: id);
    await server.start();
    _store = store;
    _server = server;
    role = SyncRole.host;
    hostError = null;
    transport = store; // o próprio host sincroniza direto com a cópia central
  }

  /// Tenta subir o servidor de novo (ex.: depois de liberar a porta no firewall).
  Future<void> restartHosting() async {
    final id = accountId;
    if (role != SyncRole.host || id == null) return;
    try {
      await _server?.stop();
      _server = null;
      await _startHosting(await _db, id);
    } catch (e) {
      hostError = '$e';
      rethrow;
    }
  }

  /// Cria uma conta nova e deixa ESTE aparelho como host. Devolve o ID.
  Future<String> createAccount() async {
    await leave(); // limpa conta/servidor anteriores (inclui a cópia central antiga)
    final db = await _db;
    final id = generateAccountId();
    await _setMeta(db, 'account_id', id);
    await _setMeta(db, 'role', 'host');
    accountId = id;
    role = SyncRole.host;
    try {
      await _startHosting(db, id);
    } catch (e) {
      hostError = '$e';
      await _clearAccount(db);
      role = SyncRole.none;
      accountId = null;
      rethrow;
    }
    await syncEnable(db);
    return id;
  }

  /// Entra numa conta existente, sincronizando com o host em [host]:[port].
  /// Testa a conexão e o ID antes de salvar qualquer coisa.
  Future<void> joinAccount({required String id, required String host, int port = kSyncPort}) async {
    if (!isValidAccountId(id)) {
      throw ArgumentError('O ID precisa ter 26 letras e números (ex.: XXXXX-XXXXX-XXXXX-XXXXX-XXXXXX).');
    }
    final canonical = normalizeAccountId(id);
    final candidate = HttpSyncTransport(host: host.trim(), port: port, accountId: canonical);
    try {
      await candidate.ping();
    } catch (_) {
      candidate.close();
      rethrow;
    }

    await leave();
    final db = await _db;
    await _setMeta(db, 'account_id', canonical);
    await _setMeta(db, 'role', 'client');
    await _setMeta(db, 'host_address', host.trim());
    await _setMeta(db, 'host_port', '$port');
    accountId = canonical;
    role = SyncRole.client;
    hostAddress = host.trim();
    hostPort = port;
    transport = candidate;
    await syncEnable(db);
  }

  /// Procura o host da conta [id] na rede local.
  Future<List<SyncHost>> findHosts(String id) => discoverSyncHosts(id);

  Future<List<String>> hostAddresses() => SyncHttpServer.localAddresses();

  /// Sai da conta neste aparelho. Os dados do app continuam; só a ligação com
  /// os outros aparelhos termina. Se este aparelho era o host, a cópia central
  /// é apagada (os outros aparelhos ficam sem onde sincronizar).
  Future<void> leave() async {
    final db = await _db;
    final wasHost = role == SyncRole.host;

    final server = _server;
    _server = null;
    await server?.stop();

    if (wasHost) {
      try {
        await (_store ?? await _newStore(db)).wipe();
      } catch (e) {
        debugPrint('Erro ao apagar a cópia central: $e');
      }
    }
    _store = null;

    final t = transport;
    if (t is HttpSyncTransport) t.close();
    transport = null;

    await _clearAccount(db);
    role = SyncRole.none;
    accountId = null;
    hostAddress = null;
    hostError = null;
  }

  Future<void> _clearAccount(Database db) async {
    for (final key in const ['account_id', 'role', 'host_address', 'host_port']) {
      await _setMeta(db, key, '');
    }
    await syncDisable(db);
  }

  Future<SyncStatus> status() async => syncStatus(await _db);

  Future<SyncReport> _run(SyncTransport t) async {
    final engine = SyncEngine(
      db: await _db,
      transport: t,
      saveMedia: (bytes, extension, isImage) =>
          MediaStorageService.saveBytes(bytes, extension, isImage: isImage),
    );
    return engine.sync();
  }

  /// Sincroniza agora. Se o host não responde (o IP dele pode ter mudado),
  /// procura de novo na rede e tenta mais uma vez.
  Future<SyncReport> syncNow() async {
    final t = transport;
    if (t == null) throw StateError('Nenhuma conta de sincronização configurada neste aparelho.');
    try {
      return await _run(t);
    } on SyncAuthException {
      rethrow;
    } on Exception catch (e) {
      final network = e is SocketException || e is TimeoutException || e is HttpException;
      if (!network || !await _rediscover()) rethrow;
      return await _run(transport!);
    }
  }

  Future<bool> _rediscover() async {
    final id = accountId;
    if (role != SyncRole.client || id == null) return false;
    final hosts = await discoverSyncHosts(id);
    if (hosts.isEmpty) return false;

    final found = hosts.first;
    final db = await _db;
    await _setMeta(db, 'host_address', found.address);
    await _setMeta(db, 'host_port', '${found.port}');
    final old = transport;
    if (old is HttpSyncTransport) old.close();
    hostAddress = found.address;
    hostPort = found.port;
    transport = HttpSyncTransport(host: found.address, port: found.port, accountId: id);
    return true;
  }
}
