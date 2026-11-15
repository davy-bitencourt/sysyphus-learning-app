import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../database_helper.dart';
import 'media_storage_service.dart';
import '../sync/sync_auth.dart';
import '../sync/sync_engine.dart';
import '../sync/sync_host.dart';
import '../sync/sync_http_transport_web.dart';
import '../sync/sync_models.dart';
import '../sync/sync_schema.dart';

enum SyncRole { none, host, client }

/// Browser-only account client. Hosting needs dart:io and remains available
/// on desktop/mobile; no unsupported socket operation is attempted here.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  SyncTransport? transport;
  SyncRole role = SyncRole.none;
  String? accountId;
  String? hostAddress;
  int hostPort = kSyncPort;
  String? hostError;
  Future<SyncReport>? _running;

  bool get hasAccount => accountId != null && accountId!.isNotEmpty;
  bool get isConfigured => transport != null;
  bool get isHosting => false;
  String? get discoveryError => null;
  String get accountIdFormatted => formatAccountId(accountId ?? '');
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<void> init() async {
    try {
      final db = await _db;
      final id = await getSyncMeta(db, 'account_id');
      if (id.isEmpty) return;
      accountId = id;
      final roleText = await getSyncMeta(db, 'role');
      if (roleText == 'client') {
        final host = await getSyncMeta(db, 'host_address');
        if (host.isEmpty) return;
        role = SyncRole.client;
        final port = int.tryParse(await getSyncMeta(db, 'host_port')) ?? kSyncPort;
        _useClientTransport(WebHttpSyncTransport(host: host, port: port, accountId: id));
      } else if (roleText == 'host') {
        role = SyncRole.host;
        hostError = 'Hospedagem de servidor não é suportada no navegador.';
      }
    } catch (e) {
      hostError = '$e';
      debugPrint('Erro ao iniciar sincronização Web: $e');
    }
  }

  Future<String> createAccount() async =>
      throw UnsupportedError('No navegador, entre em uma conta criada no aplicativo para computador.');

  Future<void> restartHosting() async =>
      throw UnsupportedError('Um navegador não pode hospedar o servidor de sincronização local.');

  Future<List<SyncHost>> findHosts(String id) async => <SyncHost>[];
  Future<List<String>> hostAddresses() async => <String>[];

  Future<void> joinAccount({required String id, required String host, int port = kSyncPort}) async {
    if (!isValidAccountId(id)) {
      throw ArgumentError('O ID precisa ter 26 letras e números.');
    }
    final canonical = normalizeAccountId(id);
    final candidate = WebHttpSyncTransport(host: host.trim(), port: port, accountId: canonical);
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
    await setSyncMeta(db, 'host_address', candidate.host);
    await setSyncMeta(db, 'host_port', '${candidate.port}');
    accountId = canonical;
    role = SyncRole.client;
    _useClientTransport(candidate);
    await syncEnable(db);
  }

  Future<void> leave() async {
    final db = await _db;
    _closeTransport();
    for (final key in const ['account_id', 'role', 'host_address', 'host_port']) {
      await setSyncMeta(db, key, '');
    }
    await syncDisable(db);
    role = SyncRole.none;
    accountId = null;
    hostAddress = null;
    hostError = null;
  }

  Future<SyncStatus> status() async => syncStatus(await _db);

  Future<SyncReport> syncNow() {
    final running = _running;
    if (running != null) return running;
    final task = _syncOnce().whenComplete(() => _running = null);
    _running = task;
    return task;
  }

  Future<SyncReport> _syncOnce() async {
    if (!hasAccount || transport is! WebHttpSyncTransport) {
      throw StateError('Conecte-se a uma conta de sincronização primeiro.');
    }
    await (transport! as WebHttpSyncTransport).ping();
    final db = await _db;
    if (await getSyncMeta(db, 'enabled') != '1') await syncEnable(db);
    return SyncEngine(
      db: db,
      transport: transport!,
      saveMedia: (bytes, extension, isImage) =>
          MediaStorageService.saveBytes(bytes, extension, isImage: isImage),
    ).sync();
  }

  void _useClientTransport(WebHttpSyncTransport next) {
    _closeTransport();
    transport = next;
    hostAddress = next.host;
    hostPort = next.port;
  }

  void _closeTransport() {
    final previous = transport;
    if (previous is WebHttpSyncTransport) previous.close();
    transport = null;
  }
}
