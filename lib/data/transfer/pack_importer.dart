import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:sqflite/sqflite.dart';

import '../database_helper.dart';
import '../models/field_model.dart';
import '../services/media_storage_service.dart';
import 'pack_models.dart';

/// Abre um .zip e devolve nome da entrada -> bytes (só arquivos).
/// Lança [FormatException] se o arquivo não for um zip válido.
Map<String, List<int>> unzipPack(List<int> zipBytes) {
  Archive? archive;
  try {
    archive = ZipDecoder().decodeBytes(zipBytes);
  } catch (_) {
    archive = null;
  }
  if (archive == null) {
    throw const FormatException('O arquivo escolhido não é um .zip válido.');
  }

  final files = <String, List<int>>{};
  for (final entry in archive) {
    if (!entry.isFile) continue;
    final List<int>? data = entry.readBytes();
    if (data == null) continue;
    files[entry.name.replaceAll('\\', '/')] = data;
  }
  return files;
}

// ---------------------------------------------------------------------------
// Plano de importação (o que VAI acontecer, calculado sem gravar nada)
// ---------------------------------------------------------------------------

class TemplateDecision {
  final PackTemplate template;

  /// Id de um template já existente e idêntico (reaproveitado), ou null.
  final int? reuseId;

  /// Rótulo normalizado -> id do campo (só quando [reuseId] != null).
  final Map<String, String> reuseFieldIds;

  /// Nome com que o template será criado (se não for reaproveitado).
  final String finalName;

  /// Já existe um com o mesmo nome, mas com campos diferentes.
  final bool isCopy;

  const TemplateDecision({
    required this.template,
    required this.reuseId,
    required this.reuseFieldIds,
    required this.finalName,
    required this.isCopy,
  });

  bool get isReused => reuseId != null;
}

class PackImportPlan {
  final PackParseResult parsed;
  final Map<String, TemplateDecision> templates; // chave: nome normalizado
  final Map<String, int> existingPackages; // título normalizado -> id
  final Map<String, int> existingSessions;
  final Map<String, int> existingTags;
  final List<PackQuestion> questionsToAdd;
  final int duplicatesSkipped;
  final Set<String> mediaToCopy;
  final List<String> notes;

  const PackImportPlan({
    required this.parsed,
    required this.templates,
    required this.existingPackages,
    required this.existingSessions,
    required this.existingTags,
    required this.questionsToAdd,
    required this.duplicatesSkipped,
    required this.mediaToCopy,
    required this.notes,
  });

  int get templatesReused => templates.values.where((d) => d.isReused).length;
  int get templatesCopied => templates.values.where((d) => d.isCopy).length;
  int get templatesNew => templates.values.where((d) => !d.isReused && !d.isCopy).length;

  int get packagesNew {
    final keys = <String>{};
    for (final p in parsed.data.packages) {
      final k = normalizeText(p.title);
      if (!existingPackages.containsKey(k)) keys.add(k);
    }
    return keys.length;
  }

  int get packagesExisting {
    final keys = <String>{};
    for (final p in parsed.data.packages) {
      final k = normalizeText(p.title);
      if (existingPackages.containsKey(k)) keys.add(k);
    }
    return keys.length;
  }

  int get sessionsNew =>
      parsed.data.sessions.where((s) => !existingSessions.containsKey(normalizeText(s.title))).length;

  int get sessionsExisting => parsed.data.sessions.length - sessionsNew;

  int get tagsNew {
    final needed = <String>{};
    for (final q in questionsToAdd) {
      if (q.tag != null) needed.add(normalizeText(q.tag!));
    }
    for (final s in parsed.data.sessions) {
      if (existingSessions.containsKey(normalizeText(s.title))) continue;
      for (final f in s.tagFilters) {
        needed.add(normalizeText(f.tag));
      }
    }
    return needed.where((k) => !existingTags.containsKey(k)).length;
  }

  bool get hasChanges =>
      questionsToAdd.isNotEmpty ||
      templatesNew + templatesCopied > 0 ||
      packagesNew > 0 ||
      sessionsNew > 0;
}

class ImportOutcome {
  final int questionsAdded;
  final int packagesCreated;
  final int templatesCreated;
  final int sessionsCreated;
  final int tagsCreated;
  final int duplicatesSkipped;
  const ImportOutcome({
    required this.questionsAdded,
    required this.packagesCreated,
    required this.templatesCreated,
    required this.sessionsCreated,
    required this.tagsCreated,
    required this.duplicatesSkipped,
  });
}

bool _sameStructure(PackTemplate a, TemplateModel b) {
  if (a.fields.length != b.fields.length) return false;
  for (var i = 0; i < a.fields.length; i++) {
    final x = a.fields[i];
    final y = b.fields[i];
    if (normalizeText(x.label) != normalizeText(y.label)) return false;
    if (x.type != y.type || x.section != y.section) return false;
    if (x.isGradable && x.optionCount != y.optionCount) return false;
  }
  return true;
}

/// Compara o pacote com o que já existe no banco e decide o que será criado,
/// reaproveitado ou ignorado. Não grava nada.
Future<PackImportPlan> buildImportPlan(PackParseResult parsed) async {
  final db = await DatabaseHelper.instance.database;
  final notes = <String>[];

  // ---- templates existentes ----
  final existingTemplates = <TemplateModel>[];
  for (final r in await db.rawQuery('SELECT id, template FROM templates')) {
    try {
      existingTemplates.add(TemplateModel.fromJson(r['id'] as int, r['template'] as String));
    } catch (_) {
      // template ilegível no banco: ignora
    }
  }

  final takenNames = <String>{for (final e in existingTemplates) normalizeText(e.name)};
  final decisions = <String, TemplateDecision>{};

  for (final t in parsed.data.templates) {
    final key = normalizeText(t.name);
    final sameName = existingTemplates.where((e) => normalizeText(e.name) == key).toList();

    TemplateModel? match;
    for (final e in sameName) {
      if (_sameStructure(t, e)) {
        match = e;
        break;
      }
    }

    if (match != null) {
      final ids = <String, String>{};
      for (final f in match.fields) {
        ids.putIfAbsent(normalizeText(f.label), () => f.id);
      }
      decisions[key] = TemplateDecision(
        template: t,
        reuseId: match.id,
        reuseFieldIds: ids,
        finalName: match.name,
        isCopy: false,
      );
    } else if (sameName.isNotEmpty) {
      var n = 2;
      var candidate = '${t.name} ($n)';
      while (takenNames.contains(normalizeText(candidate))) {
        n++;
        candidate = '${t.name} ($n)';
      }
      takenNames.add(normalizeText(candidate));
      decisions[key] = TemplateDecision(
        template: t,
        reuseId: null,
        reuseFieldIds: const {},
        finalName: candidate,
        isCopy: true,
      );
      notes.add("O template '${t.name}' já existe com campos diferentes: será criado como '$candidate'.");
    } else {
      takenNames.add(key);
      decisions[key] = TemplateDecision(
        template: t,
        reuseId: null,
        reuseFieldIds: const {},
        finalName: t.name,
        isCopy: false,
      );
    }
  }

  // ---- pacotes, sessões e tags existentes ----
  Future<Map<String, int>> loadIds(String sql) async {
    final map = <String, int>{};
    for (final r in await db.rawQuery(sql)) {
      final id = r['id'] as int;
      final title = (r['title'] as String?) ?? '';
      map.putIfAbsent(normalizeText(title), () => id);
    }
    return map;
  }

  final existingPackages = await loadIds('SELECT id, title FROM package');
  final existingSessions = await loadIds('SELECT id, title FROM session');
  final existingTags = await loadIds('SELECT id, title FROM tag');

  for (final p in parsed.data.packages) {
    if (existingPackages.containsKey(normalizeText(p.title))) {
      notes.add("O pacote '${p.title}' já existe: as questões novas serão adicionadas a ele.");
    }
  }

  // ---- questões: tira as que já existem (importar duas vezes não duplica) ----
  final statementCache = <String, Set<String>>{};
  Future<Set<String>> existingStatements(int packageId, int templateId) async {
    final cacheKey = '$packageId|$templateId';
    final cached = statementCache[cacheKey];
    if (cached != null) return cached;
    final set = <String>{};
    final rows = await db.rawQuery(
      'SELECT questions FROM question WHERE package_id = ? AND template_id = ?',
      [packageId, templateId],
    );
    for (final r in rows) {
      try {
        final decoded = jsonDecode(r['questions'] as String);
        if (decoded is Map && decoded['statement'] is String) {
          set.add(normalizeText(decoded['statement'] as String));
        }
      } catch (_) {
        // linha com JSON inválido: ignora
      }
    }
    statementCache[cacheKey] = set;
    return set;
  }

  final toAdd = <PackQuestion>[];
  final seenInPack = <String>{};
  var skipped = 0;
  for (final pkg in parsed.data.packages) {
    final pkgKey = normalizeText(pkg.title);
    final pkgId = existingPackages[pkgKey];
    for (final q in pkg.questions) {
      final tplKey = normalizeText(q.templateName);
      final decision = decisions[tplKey];
      final stmt = normalizeText(q.statement);

      if (!seenInPack.add('$pkgKey|$tplKey|$stmt')) {
        skipped++;
        continue;
      }
      final reuseId = decision?.reuseId;
      if (pkgId != null && reuseId != null) {
        final existing = await existingStatements(pkgId, reuseId);
        if (existing.contains(stmt)) {
          skipped++;
          continue;
        }
      }
      toAdd.add(q);
    }
  }
  if (skipped > 0) {
    notes.add('$skipped questão(ões) já existem e serão ignoradas.');
  }

  // ---- mídias que realmente serão copiadas ----
  final media = <String>{};
  for (final q in toAdd) {
    final decision = decisions[normalizeText(q.templateName)];
    if (decision == null) continue;
    for (final f in decision.template.fields) {
      if (!f.isMedia) continue;
      final v = q.values[normalizeText(f.label)];
      if (v is String && v.isNotEmpty) media.add(v);
    }
  }

  return PackImportPlan(
    parsed: parsed,
    templates: decisions,
    existingPackages: existingPackages,
    existingSessions: existingSessions,
    existingTags: existingTags,
    questionsToAdd: toAdd,
    duplicatesSkipped: skipped,
    mediaToCopy: media,
    notes: notes,
  );
}

// ---------------------------------------------------------------------------
// Gravação
// ---------------------------------------------------------------------------

/// Grava o plano. Tudo-ou-nada: as mídias são copiadas primeiro e, se algo
/// falhar, são apagadas; o banco usa uma única transação.
Future<ImportOutcome> commitImport(PackImportPlan plan, Map<String, List<int>> files) async {
  final db = await DatabaseHelper.instance.database;
  final savedMedia = <String>[];

  try {
    // 1) copia as mídias para o armazenamento do app
    final mediaPaths = <String, String>{};
    for (final zipPath in plan.mediaToCopy) {
      final bytes = files[zipPath];
      if (bytes == null) continue;
      final ext = packExtOf(zipPath);
      final saved = await MediaStorageService.saveBytes(
        bytes,
        ext,
        isImage: kPackImageExts.contains(ext),
      );
      savedMedia.add(saved);
      mediaPaths[zipPath] = saved;
    }

    var tagsCreated = 0;
    var templatesCreated = 0;
    var sessionsCreated = 0;
    var packagesCreated = 0;
    var questionsAdded = 0;

    // 2) grava tudo numa transação
    await db.transaction((Transaction txn) async {
      final tagIds = Map<String, int>.from(plan.existingTags);

      Future<int> ensureTag(String title) async {
        final key = normalizeText(title);
        final cached = tagIds[key];
        if (cached != null) return cached;
        final id = await txn.rawInsert('INSERT INTO tag (title) VALUES (?)', [title]);
        tagIds[key] = id;
        tagsCreated++;
        return id;
      }

      // templates
      final templateIds = <String, int>{};
      final fieldIdsByTemplate = <String, Map<String, String>>{};
      final stamp = DateTime.now().microsecondsSinceEpoch;
      var templateIndex = 0;
      for (final entry in plan.templates.entries) {
        final d = entry.value;
        final reuseId = d.reuseId;
        if (reuseId != null) {
          templateIds[entry.key] = reuseId;
          fieldIdsByTemplate[entry.key] = d.reuseFieldIds;
          continue;
        }

        final ids = <String, String>{};
        final defs = <FieldDefinition>[];
        for (var i = 0; i < d.template.fields.length; i++) {
          final f = d.template.fields[i];
          final labelKey = normalizeText(f.label);
          final isStatement = labelKey == 'enunciado';
          final id = isStatement ? FieldDefinition.statementId : 'field_${stamp}_${templateIndex}_$i';
          ids[labelKey] = id;
          defs.add(FieldDefinition(
            id: id,
            type: f.type,
            label: isStatement ? 'Enunciado' : f.label,
            section: isStatement ? FieldSection.question : f.section,
            optionCount: f.optionCount,
            maxWidth: f.maxWidth,
            maxHeight: f.maxHeight,
          ));
        }
        final json = TemplateModel(name: d.finalName, fields: defs).toJsonString();
        final newId = await txn.rawInsert('INSERT INTO templates (template) VALUES (?)', [json]);
        templateIds[entry.key] = newId;
        fieldIdsByTemplate[entry.key] = ids;
        templatesCreated++;
        templateIndex++;
      }

      // sessões (as que já existem são reaproveitadas sem alteração)
      final sessionIds = Map<String, int>.from(plan.existingSessions);
      for (final s in plan.parsed.data.sessions) {
        final key = normalizeText(s.title);
        if (sessionIds.containsKey(key)) continue;

        final filters = <Map<String, int>>[];
        for (final f in s.tagFilters) {
          filters.add({'tag_id': await ensureTag(f.tag), 'quantity': f.quantity});
        }
        final id = await txn.rawInsert(
          'INSERT INTO session (title, time_limit, total_q, tag_filters) VALUES (?, ?, ?, ?)',
          [s.title, s.timeLimitMinutes?.toString(), s.totalQuestions, filters.isEmpty ? null : jsonEncode(filters)],
        );
        sessionIds[key] = id;
        sessionsCreated++;
      }

      // pacotes (os que já existem recebem as questões novas)
      final packageIds = Map<String, int>.from(plan.existingPackages);
      for (final p in plan.parsed.data.packages) {
        final key = normalizeText(p.title);
        if (packageIds.containsKey(key)) continue;

        final sessionTitle = p.sessionTitle;
        final sessionId = sessionTitle == null ? null : sessionIds[normalizeText(sessionTitle)];
        final id = await txn.rawInsert(
          'INSERT INTO package (session_id, title) VALUES (?, ?)',
          [sessionId, p.title],
        );
        packageIds[key] = id;
        packagesCreated++;
      }

      // questões
      for (final q in plan.questionsToAdd) {
        final tplKey = normalizeText(q.templateName);
        final decision = plan.templates[tplKey];
        final fieldIds = fieldIdsByTemplate[tplKey];
        final templateId = templateIds[tplKey];
        final packageId = packageIds[normalizeText(q.packageTitle)];
        if (decision == null || fieldIds == null || templateId == null || packageId == null) continue;

        // Mesmo formato que a tela de edição grava: uma chave por campo.
        final values = <String, Object?>{};
        for (final f in decision.template.fields) {
          final fid = fieldIds[normalizeText(f.label)];
          if (fid == null) continue;
          final provided = q.values[normalizeText(f.label)];
          if (f.isGradable) {
            final list = provided is List<PackOption> ? provided : const <PackOption>[];
            values[fid] = [
              for (final o in list) {'text': o.text, 'correct': o.correct},
            ];
          } else if (f.isMedia) {
            values[fid] = (provided is String && provided.isNotEmpty) ? mediaPaths[provided] : null;
          } else {
            values[fid] = provided is String ? provided : '';
          }
        }

        final tag = q.tag;
        final tagId = tag == null ? null : await ensureTag(tag);
        final questionId = await txn.rawInsert(
          'INSERT INTO question (package_id, tag_id, template_id, questions) VALUES (?, ?, ?, ?)',
          [packageId, tagId, templateId, jsonEncode(values)],
        );
        await txn.rawInsert('INSERT INTO state (question_id) VALUES (?)', [questionId]);
        questionsAdded++;
      }
    });

    return ImportOutcome(
      questionsAdded: questionsAdded,
      packagesCreated: packagesCreated,
      templatesCreated: templatesCreated,
      sessionsCreated: sessionsCreated,
      tagsCreated: tagsCreated,
      duplicatesSkipped: plan.duplicatesSkipped,
    );
  } catch (_) {
    for (final path in savedMedia) {
      await MediaStorageService.delete(path);
    }
    rethrow;
  }
}
