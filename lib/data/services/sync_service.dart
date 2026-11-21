import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../database_helper.dart';
import 'media_storage_service.dart';
import '../sync/sync_auth.dart';
import '../sync/sync_discovery.dart';
import '../sync/sync_engine.dart';
import '../sync/sync_http_server.dart';
import '../sync/sync_http_transport.dart';
import '../sync/sync_models.dart';
import '../sync/sync_schema.dart';
import '../sync/sync_store.dart';

enum SyncRole { none, host, client }

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  SyncTransport? transport;
  SyncRole role = SyncRole.none;
  String? accountId;
  String? hostAddress;
  int hostPort = kSyncPort;

  String? hostError;

  SyncHttpServer? _server;
  SqliteSyncStore? _store;

  bool get isSupported => !kIsWeb;
  bool get hasAccount => accountId != null && accountId!.isNotEmpty;
  bool get isConfigured => transport != null;
  bool get isHosting => _server?.isRunning ?? false;
  String? get discoveryError => _server?.discoveryError;
  String get accountIdFormatted => formatAccountId(accountId ?? '');

  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<void> init() async {
    if (!isSupported) return;
    try {
      final db = await _db;
      final id = await getSyncMeta(db, 'account_id');
      if (id.isEmpty) return;
      accountId = id;

      final roleText = await getSyncMeta(db, 'role');
      if (roleText == 'host') {
        role = SyncRole.host;
        await _startHosting(db, id);
      } else if (roleText == 'client') {
        final host = await getSyncMeta(db, 'host_address');
        if (host.isEmpty) return;
        role = SyncRole.client;
        final port = int.tryParse(await getSyncMeta(db, 'host_port')) ?? kSyncPort;
        _useClientTransport(HttpSyncTransport(host: host, port: port, accountId: id));
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
    hostError = null;
    transport = store; 
  }

  Future<void> restartHosting() async {
    _requireSupport();
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

  Future<String> createAccount() async {
    _requireSupport();
    await leave(); 
    final db = await _db;
    final id = generateAccountId();
    await setSyncMeta(db, 'account_id', id);
    await setSyncMeta(db, 'role', 'host');
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

  Future<void> joinAccount({required String id, required String host, int port = kSyncPort}) async {
    _requireSupport();
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
    await setSyncMeta(db, 'account_id', canonical);
    await setSyncMeta(db, 'role', 'client');
    await _saveHost(db, candidate.host, candidate.port);
    accountId = canonical;
    role = SyncRole.client;
    _useClientTransport(candidate);
    await syncEnable(db);
  }

  Future<List<SyncHost>> findHosts(String id) => discoverSyncHosts(id);

  Future<List<String>> hostAddresses() => localIPv4Addresses();

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

    _closeTransport();

    await _clearAccount(db);
    role = SyncRole.none;
    accountId = null;
    hostAddress = null;
    hostError = null;
  }

  Future<void> _clearAccount(Database db) async {
    for (final key in const ['account_id', 'role', 'host_address', 'host_port']) {
      await setSyncMeta(db, key, '');
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

  Future<SyncReport>? _running;

  Future<SyncReport> syncNow() {
    if (!isSupported) {
      return Future.error(UnsupportedError('A sincronização não está disponível no navegador.'));
    }
    final current = _running;
    if (current != null) return current;
    final run = _syncOnce().whenComplete(() => _running = null);
    _running = run;
    return run;
  }

  Future<SyncReport> _syncOnce() async {
    if (!hasAccount) throw StateError('Nenhuma conta de sincronização configurada neste aparelho.');

    await _checkConnection();

    final db = await _db;
    if (await getSyncMeta(db, 'enabled') != '1') await syncEnable(db);

    return _run(transport!);
  }

  Future<void> _checkConnection() async {
    if (role == SyncRole.host) {
      if (!isHosting || transport == null) await restartHosting();
      return;
    }

    final t = transport;
    if (t is! HttpSyncTransport) {
      throw StateError('Este aparelho não está ligado a nenhum host. Entre na conta de novo.');
    }
    try {
      await t.ping();
    } on Exception catch (e) {
      final network = e is SocketException || e is TimeoutException || e is HttpException;
      if (!network || !await _rediscover()) rethrow;
      await (transport as HttpSyncTransport).ping();
    }
  }

  Future<bool> _rediscover() async {
    final id = accountId;
    if (role != SyncRole.client || id == null) return false;
    final hosts = await discoverSyncHosts(id);
    if (hosts.isEmpty) return false;

    final found = hosts.first;
    await _saveHost(await _db, found.address, found.port);
    _useClientTransport(HttpSyncTransport(host: found.address, port: found.port, accountId: id));
    return true;
  }

  Future<void> _saveHost(Database db, String host, int port) async {
    await setSyncMeta(db, 'host_address', host);
    await setSyncMeta(db, 'host_port', '$port');
  }

  void _useClientTransport(HttpSyncTransport t) {
    _closeTransport();
    transport = t;
    hostAddress = t.host;
    hostPort = t.port;
  }

  void _closeTransport() {
    final t = transport;
    if (t is HttpSyncTransport) t.close();
    transport = null;
  }

  void _requireSupport() {
    if (!isSupported) {
      throw UnsupportedError('A sincronização não está disponível no navegador.');
    }
  }
}
