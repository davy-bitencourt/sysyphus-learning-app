import 'dart:convert';

import 'sync_models.dart';

class MemorySyncTransport implements SyncTransport {
  final Map<String, ({SyncChange change, int seq})> _records = {};
  final Map<String, List<int>> _blobs = {};
  int _seq = 0;

  int blobUploads = 0;

  int get seq => _seq;

  @override
  Future<PullResult> pull(int sinceSeq) async {
    final list = _records.values.where((r) => r.seq > sinceSeq).toList()
      ..sort((a, b) => a.seq.compareTo(b.seq));
    return PullResult(changes: [for (final r in list) r.change], latestSeq: _seq);
  }

  @override
  Future<void> push(String deviceId, List<SyncChange> changes) async {
    for (final c in changes) {
      final key = '${c.entity}|${c.uuid}';
      final current = _records[key];
      if (current != null && current.change.ts > c.ts) continue; // mais antigo: ignora
      final wire = jsonDecode(jsonEncode({...c.toJson(), 'device': deviceId}));
      _records[key] = (
        change: SyncChange.fromJson(Map<String, dynamic>.from(wire as Map)),
        seq: ++_seq,
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
