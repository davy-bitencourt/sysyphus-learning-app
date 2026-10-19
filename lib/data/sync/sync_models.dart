/// Entidades sincronizadas, em ordem de dependência (pais antes dos filhos).
const List<String> kSyncEntities = [
  'tag',
  'templates',
  'session',
  'package',
  'question',
  'state',
  'revlog',
];

int syncEntityIndex(String entity) => kSyncEntities.indexOf(entity);

/// Uma mudança que viaja entre aparelhos. `data` usa só uuids (nunca ids
/// locais) e referências de mídia por hash (`blob:<sha256>.<ext>`).
class SyncChange {
  final String entity;
  final String uuid;
  final String op; // 'upsert' | 'delete'
  final int ts; // updated_at em ms (relógio do aparelho que editou)
  final Map<String, dynamic>? data;
  final String device;

  const SyncChange({
    required this.entity,
    required this.uuid,
    required this.op,
    required this.ts,
    required this.data,
    required this.device,
  });

  Map<String, dynamic> toJson() => {
        'entity': entity,
        'uuid': uuid,
        'op': op,
        'ts': ts,
        'data': data,
        'device': device,
      };

  factory SyncChange.fromJson(Map<String, dynamic> json) => SyncChange(
        entity: json['entity'] as String,
        uuid: json['uuid'] as String,
        op: json['op'] as String,
        ts: (json['ts'] as num).toInt(),
        data: json['data'] == null ? null : Map<String, dynamic>.from(json['data'] as Map),
        device: (json['device'] as String?) ?? '',
      );
}

class PullResult {
  final List<SyncChange> changes;
  final int latestSeq;
  const PullResult({required this.changes, required this.latestSeq});
}

/// Contrato com o servidor. O motor não sabe qual é: Supabase, PocketBase ou
/// um servidor próprio só precisam implementar estes 5 métodos.
abstract class SyncTransport {
  /// Registros atuais (um por entidade+uuid) alterados depois de [sinceSeq].
  Future<PullResult> pull(int sinceSeq);

  /// Grava as mudanças. O servidor guarda o registro de maior `ts` por
  /// entidade+uuid (empate: o último a chegar vale).
  Future<void> push(String deviceId, List<SyncChange> changes);

  Future<bool> hasBlob(String hash);
  Future<void> putBlob(String hash, List<int> bytes);
  Future<List<int>?> getBlob(String hash);
}

class SyncReport {
  int applied = 0; // mudanças remotas aplicadas
  int skipped = 0; // ignoradas (referência faltando ou exclusão local mais nova)
  int kept = 0; // a edição local era mais nova e foi mantida
  int adopted = 0; // itens de mesmo nome fundidos na primeira ligação
  int pushed = 0; // mudanças locais enviadas

  @override
  String toString() =>
      'aplicadas $applied, mantidas $kept, ignoradas $skipped, fundidas $adopted, enviadas $pushed';
}

class SyncStatus {
  final bool enabled;
  final String deviceId;
  final int pendingChanges;
  final DateTime? lastSync;
  const SyncStatus({
    required this.enabled,
    required this.deviceId,
    required this.pendingChanges,
    required this.lastSync,
  });
}
