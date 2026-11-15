import 'dart:convert';

import 'package:http/http.dart' as http;

import 'sync_auth.dart';
import 'sync_errors.dart';
import 'sync_models.dart';

/// Browser transport for the existing signed HTTP synchronization protocol.
/// The desktop host must allow CORS, and the page's security context must
/// permit access to its network address.
class WebHttpSyncTransport implements SyncTransport {
  WebHttpSyncTransport({
    required this.host,
    required this.accountId,
    this.port = kSyncPort,
    this.timeout = const Duration(seconds: 30),
  });

  final String host;
  final String accountId;
  final int port;
  final Duration timeout;
  final http.Client _client = http.Client();

  Uri _uri(String path) => Uri(scheme: 'http', host: host, port: port, path: path);

  Future<http.Response> _send(String method, String path, [List<int> body = const []]) async {
    final time = DateTime.now().millisecondsSinceEpoch;
    final request = http.Request(method, _uri(path))
      ..headers['x-sysy-time'] = '$time'
      ..headers['x-sysy-sig'] = signRequest(accountId, method, path, time, body)
      ..bodyBytes = body;
    final stream = await _client.send(request).timeout(timeout);
    final response = await http.Response.fromStream(stream).timeout(timeout);
    if (response.statusCode == 401) throw const SyncAuthException();
    return response;
  }

  http.Response _ok(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('O servidor respondeu ${response.statusCode}');
    }
    return response;
  }

  Future<void> ping() async {
    _ok(await _send('GET', '/v1/ping'));
  }

  @override
  Future<PullResult> pull(int sinceSeq) async {
    final response = _ok(await _send('POST', '/v1/pull', utf8.encode(jsonEncode({'since': sinceSeq}))));
    final j = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return PullResult(
      changes: [
        for (final change in j['changes'] as List)
          SyncChange.fromJson(Map<String, dynamic>.from(change as Map)),
      ],
      latestSeq: (j['latest'] as num).toInt(),
    );
  }

  @override
  Future<void> push(String deviceId, List<SyncChange> changes) async {
    _ok(await _send('POST', '/v1/push', utf8.encode(jsonEncode({
      'device': deviceId,
      'changes': [for (final c in changes) c.toJson()],
    }))));
  }

  @override
  Future<bool> hasBlob(String hash) async =>
      (await _send('HEAD', '/v1/blob/$hash')).statusCode == 200;

  @override
  Future<void> putBlob(String hash, List<int> bytes) async {
    _ok(await _send('PUT', '/v1/blob/$hash', bytes));
  }

  @override
  Future<List<int>?> getBlob(String hash) async {
    final response = await _send('GET', '/v1/blob/$hash');
    return response.statusCode == 200 ? response.bodyBytes : null;
  }

  void close() => _client.close();
}
