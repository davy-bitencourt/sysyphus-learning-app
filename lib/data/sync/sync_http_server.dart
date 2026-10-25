import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'sync_auth.dart';
import 'sync_discovery.dart';
import 'sync_models.dart';

/// Servidor de sincronização: HTTP para os dados e UDP para ser achado na
/// rede. Não depende de Flutter nem de tela, então o mesmo código pode rodar
/// num servidor na internet no futuro (atrás de HTTPS).
///
/// Toda requisição precisa de assinatura válida do ID da conta (ver
/// signRequest). Sem ela, a resposta é 401.
class SyncHttpServer {
  SyncHttpServer({
    required this.transport,
    required this.accountId,
    this.port = kSyncPort,
    this.enableDiscovery = true,
  });

  /// Onde os dados ficam (SqliteSyncStore no app; MemorySyncTransport nos testes).
  final SyncTransport transport;
  final String accountId;
  final int port;
  final bool enableDiscovery;

  HttpServer? _server;
  RawDatagramSocket? _udp;

  /// Preenchido se a descoberta automática não pôde ser ligada (o HTTP segue
  /// funcionando; o outro aparelho precisa então do endereço digitado).
  String? discoveryError;

  bool get isRunning => _server != null;
  int get boundPort => _server?.port ?? port;

  static const int _maxBody = 200 * 1024 * 1024;
  static final RegExp _blobRe = RegExp(r'^/v1/blob/([0-9a-f]{64})$');

  Future<void> start() async {
    if (_server != null) return;
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server = server;
    server.listen(_handle, onError: (Object _) {});
    if (enableDiscovery) await _startDiscovery();
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _udp?.close();
    _udp = null;
    await server?.close(force: true);
  }

  Future<void> _startDiscovery() async {
    try {
      _udp = await startDiscoveryResponder(accountId, () => boundPort);
    } catch (e) {
      discoveryError = '$e';
    }
  }

  Future<List<int>?> _readBody(HttpRequest req) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in req) {
      builder.add(chunk);
      if (builder.length > _maxBody) return null;
    }
    return builder.takeBytes();
  }

  bool _authorized(HttpRequest req, String path, List<int> body) {
    final timeText = req.headers.value('x-sysy-time');
    final signature = req.headers.value('x-sysy-sig');
    if (timeText == null || signature == null) return false;
    final t = int.tryParse(timeText);
    if (t == null) return false;
    if ((DateTime.now().millisecondsSinceEpoch - t).abs() > kSyncClockToleranceMs) return false;
    final expected = signRequest(accountId, req.method, path, t, body);
    return constantTimeEquals(expected, signature);
  }

  Future<void> _sendStatus(HttpResponse res, int status) async {
    res.statusCode = status;
    await res.close();
  }

  Future<void> _sendJson(HttpResponse res, int status, Object json) async {
    res.statusCode = status;
    res.headers.contentType = ContentType.json;
    res.add(utf8.encode(jsonEncode(json)));
    await res.close();
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
      final body = await _readBody(req);
      if (body == null) {
        await _sendJson(res, 413, {'error': 'corpo grande demais'});
        return;
      }
      final path = req.uri.path;
      if (!_authorized(req, path, body)) {
        await _sendJson(res, 401, {'error': 'unauthorized'});
        return;
      }

      final method = req.method.toUpperCase();

      if (method == 'GET' && path == '/v1/ping') {
        await _sendJson(res, 200, {'ok': true, 'app': 'sysyphus', 'version': 1});
        return;
      }

      if (method == 'POST' && path == '/v1/pull') {
        final j = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
        final result = await transport.pull((j['since'] as num).toInt());
        await _sendJson(res, 200, {
          'changes': [for (final c in result.changes) c.toJson()],
          'latest': result.latestSeq,
        });
        return;
      }

      if (method == 'POST' && path == '/v1/push') {
        final j = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
        final changes = [
          for (final e in (j['changes'] as List)) SyncChange.fromJson(Map<String, dynamic>.from(e as Map)),
        ];
        await transport.push(j['device'] as String, changes);
        await _sendJson(res, 200, {'ok': true});
        return;
      }

      final blob = _blobRe.firstMatch(path);
      if (blob != null) {
        final hash = blob.group(1)!;
        if (method == 'HEAD') {
          await _sendStatus(res, await transport.hasBlob(hash) ? 200 : 404);
          return;
        }
        if (method == 'GET') {
          final bytes = await transport.getBlob(hash);
          if (bytes == null) {
            await _sendStatus(res, 404);
          } else {
            res.statusCode = 200;
            res.headers.contentType = ContentType.binary;
            res.add(bytes);
            await res.close();
          }
          return;
        }
        if (method == 'PUT') {
          try {
            await transport.putBlob(hash, body);
          } on ArgumentError {
            await _sendJson(res, 400, {'error': 'hash não confere'});
            return;
          }
          await _sendJson(res, 200, {'ok': true});
          return;
        }
      }

      await _sendJson(res, 404, {'error': 'not found'});
    } catch (e) {
      try {
        await _sendJson(res, 500, {'error': '$e'});
      } catch (_) {
        // a conexão já caiu: nada a fazer
      }
    }
  }
}
