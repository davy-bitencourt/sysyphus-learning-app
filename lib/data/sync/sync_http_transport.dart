import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'sync_auth.dart';
import 'sync_models.dart';

/// ID recusado pelo servidor (ID errado ou relógios muito diferentes).
class SyncAuthException implements Exception {
  final String message;
  const SyncAuthException([this.message = 'ID incorreto ou relógios dos aparelhos muito diferentes.']);
  @override
  String toString() => message;
}

class _Resp {
  final int status;
  final List<int> body;
  const _Resp(this.status, this.body);
}

/// Cliente do servidor de sincronização, por HTTP com requisições assinadas.
class HttpSyncTransport implements SyncTransport {
  HttpSyncTransport({
    required this.host,
    required this.accountId,
    this.port = kSyncPort,
    this.timeout = const Duration(seconds: 30),
  });

  final String host;
  final int port;
  final String accountId;
  final Duration timeout;

  final HttpClient _client = HttpClient()..connectionTimeout = const Duration(seconds: 5);

  Future<_Resp> _send(String method, String path, [List<int> body = const []]) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    final req = await _client
        .openUrl(method, Uri(scheme: 'http', host: host, port: port, path: path))
        .timeout(timeout);
    req.headers.set('x-sysy-time', '$t');
    req.headers.set('x-sysy-sig', signRequest(accountId, method, path, t, body));
    if (body.isNotEmpty) {
      req.contentLength = body.length;
      req.add(body);
    }
    final res = await req.close().timeout(timeout);
    final builder = BytesBuilder(copy: false);
    await for (final chunk in res.timeout(timeout)) {
      builder.add(chunk);
    }
    return _Resp(res.statusCode, builder.takeBytes());
  }

  _Resp _ok(_Resp r) {
    if (r.status == 401) throw const SyncAuthException();
    if (r.status < 200 || r.status >= 300) {
      throw HttpException('O servidor respondeu ${r.status}', uri: Uri(host: host, port: port));
    }
    return r;
  }

  /// Testa a conexão e o ID. Lança se o host não responde ou recusa o ID.
  Future<void> ping() async {
    _ok(await _send('GET', '/v1/ping'));
  }

  @override
  Future<PullResult> pull(int sinceSeq) async {
    final r = _ok(await _send('POST', '/v1/pull', utf8.encode(jsonEncode({'since': sinceSeq}))));
    final j = jsonDecode(utf8.decode(r.body)) as Map<String, dynamic>;
    return PullResult(
      changes: [
        for (final e in (j['changes'] as List)) SyncChange.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
      latestSeq: (j['latest'] as num).toInt(),
    );
  }

  @override
  Future<void> push(String deviceId, List<SyncChange> changes) async {
    _ok(await _send(
      'POST',
      '/v1/push',
      utf8.encode(jsonEncode({'device': deviceId, 'changes': [for (final c in changes) c.toJson()]})),
    ));
  }

  @override
  Future<bool> hasBlob(String hash) async {
    final r = await _send('HEAD', '/v1/blob/$hash');
    if (r.status == 401) throw const SyncAuthException();
    return r.status == 200;
  }

  @override
  Future<void> putBlob(String hash, List<int> bytes) async {
    _ok(await _send('PUT', '/v1/blob/$hash', bytes));
  }

  @override
  Future<List<int>?> getBlob(String hash) async {
    final r = await _send('GET', '/v1/blob/$hash');
    if (r.status == 401) throw const SyncAuthException();
    return r.status == 200 ? r.body : null;
  }

  void close() => _client.close(force: true);
}
