import 'dart:convert';

import '../models/sync_models.dart';

class _Record {
  final String entity;
  final String uuid;
  final String op;
  final int ts;
  final String? dataJson;
  final String device;
  final int seq;
  const _Record(this.entity, this.uuid, this.op, this.ts, this.dataJson, this.device, this.seq);
}

/// Servidor falso em memória: serve para testes e para desenvolver sem
/// servidor. Passa os dados por JSON (como a rede faria) para pegar erros de
/// serialização.
class MemorySyncTransport implements SyncTransport {
  final Map<String, _Record> _records = {};
  final Map<String, List<int>> _blobs = {};
  int _seq = 0;

  /// Quantas vezes um arquivo foi realmente enviado (para testar o envio por hash).
  int blobUploads = 0;

  int get seq => _seq;

  @override
  Future<PullResult> pull(int sinceSeq) async {
    final list = _records.values.where((r) => r.seq > sinceSeq).toList()
      ..sort((a, b) => a.seq.compareTo(b.seq));
    return PullResult(
      changes: [
        for (final r in list)
          SyncChange(
            entity: r.entity,
            uuid: r.uuid,
            op: r.op,
            ts: r.ts,
            data: r.dataJson == null ? null : Map<String, dynamic>.from(jsonDecode(r.dataJson!) as Map),
            device: r.device,
          ),
      ],
      latestSeq: _seq,
    );
  }

  @override
  Future<void> push(String deviceId, List<SyncChange> changes) async {
    for (final c in changes) {
      final key = '${c.entity}|${c.uuid}';
      final current = _records[key];
      if (current != null && current.ts > c.ts) continue; // mais antigo: ignora
      _seq++;
      _records[key] = _Record(
        c.entity,
        c.uuid,
        c.op,
        c.ts,
        c.data == null ? null : jsonEncode(c.data),
        deviceId,
        _seq,
      );
    }
  }

  @override
  Future<bool> hasBlob(String hash) async => _blobs.containsKey(hash);

  @override
  Future<void> putBlob(String hash, List<int> bytes) async {
    _blobs[hash] = List<int>.from(bytes);
    blobUploads++;
  }

  @override
  Future<List<int>?> getBlob(String hash) async => _blobs[hash];
}
