import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import 'pack_models.dart';
import 'pack_reader.dart';
import 'question_codec.dart';

class PackPreview {
  final PackData data;
  final PackReport report;
  PackPreview(this.data, this.report);

  String get summary =>
      '${data.questionCount} questões, ${data.templates.length} templates, '
      '${data.packages.length} pacotes, ${data.sessions.length} sessões, '
      '${data.usedMedia.length} mídias, ${report.errors.length} erros, ${report.warnings.length} avisos';
}

class PackImporter {
  /* ---------- passo 1: ler e validar, sem gravar ---------- */
  static Future<PackPreview> preview(Uint8List zipBytes) async {
    final db = await DatabaseHelper.instance.database;
    final report = PackReport();

    final existingTpl = <String, TemplateDef>{};
    for (final row in await db.rawQuery('SELECT id, template FROM templates')) {
      final d = _decodeTemplate(row['template']);
      if (d != null) existingTpl.putIfAbsent(norm(d.name), () => d);
    }
    final existingSess = {
      for (final row in await db.rawQuery('SELECT title FROM session')) norm(row['title'].toString()),
    };

    final data = PackReader(report, existingTemplates: existingTpl, existingSessions: existingSess).read(zipBytes);
    return PackPreview(data, report);
  }

  static TemplateDef? _decodeTemplate(Object? raw) {
    try {
      return TemplateDef.fromDbJson(jsonDecode(raw as String) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /* ---------- passo 2: gravar tudo numa transação ---------- */
  static Future<ImportResult> commit(PackData data) async {
    final db = await DatabaseHelper.instance.database;

    // mídias primeiro (arquivos); se o banco falhar, apaga o que copiou
    final mediaMap = <String, String>{};
    final copied = <File>[];
    try {
      final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/media');
      await dir.create(recursive: true);
      var n = 0;
      final stamp = DateTime.now().microsecondsSinceEpoch;
      for (final path in data.usedMedia) {
        final ext = path.contains('.') ? path.substring(path.lastIndexOf('.')) : '';
        final f = File('${dir.path}/${stamp}_${n++}$ext');
        await f.writeAsBytes(data.media[path]!);
        copied.add(f);
        mediaMap[path] = f.path;
      }

      final res = await db.transaction((txn) => _write(txn, data, mediaMap));
      res.media = copied.length;
      return res;
    } catch (_) {
      for (final f in copied) {
        try {
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
      rethrow;
    }
  }

  static Future<ImportResult> _write(Transaction txn, PackData data, Map<String, String> mediaMap) async {
    final res = ImportResult();

    /* ----- tags ----- */
    final tagIds = <String, int>{
      for (final r in await txn.rawQuery('SELECT id, title FROM tag')) norm(r['title'].toString()): (r['id'] as num).toInt(),
    };
    Future<int> tagId(String name) async {
      final k = norm(name);
      final hit = tagIds[k];
      if (hit != null) return hit;
      final id = await txn.rawInsert('INSERT INTO tag (title) VALUES (?)', [name.trim()]);
      tagIds[k] = id;
      res.tagsCreated++;
      return id;
    }

    /* ----- templates ----- */
    final tplById = <int, TemplateDef>{}; // todos os conhecidos
    final tplIdByName = <String, int>{}; // norm(nome) -> id a usar nas questões
    final existingNames = <String>{};
    for (final r in await txn.rawQuery('SELECT id, template FROM templates')) {
      final d = _decodeTemplate(r['template']);
      if (d == null) continue;
      final id = (r['id'] as num).toInt();
      tplById[id] = d;
      existingNames.add(norm(d.name));
      tplIdByName.putIfAbsent(norm(d.name), () => id);
    }
    final packNames = {for (final t in data.templates) norm(t.name)};
    final existingBefore = Map<int, TemplateDef>.from(tplById);

    for (final t in data.templates) {
      final key = norm(t.name);
      final same = existingBefore.entries.where((e) => norm(e.value.name) == key).toList();
      if (same.isEmpty) {
        final def = t.withNewIds();
        final id = await txn.rawInsert('INSERT INTO templates (template) VALUES (?)', [jsonEncode(def.toDbJson())]);
        tplById[id] = def;
        tplIdByName[key] = id;
        res.templatesCreated++;
        continue;
      }
      final match = same.where((e) => e.value.sameShape(t)).toList();
      if (match.isNotEmpty) {
        tplIdByName[key] = match.first.key;
        res.templatesReused++;
        continue;
      }
      // mesmo nome, campos diferentes: cria cópia "Nome (n)"
      var n = 2;
      while (existingNames.contains(norm('${t.name} ($n)')) || packNames.contains(norm('${t.name} ($n)'))) {
        n++;
      }
      final def = t.renamed('${t.name} ($n)').withNewIds();
      existingNames.add(norm(def.name));
      final id = await txn.rawInsert('INSERT INTO templates (template) VALUES (?)', [jsonEncode(def.toDbJson())]);
      tplById[id] = def;
      tplIdByName[key] = id;
      res.templatesCreated++;
    }

    /* ----- sessões ----- */
    final sessIds = <String, int>{
      for (final r in await txn.rawQuery('SELECT id, title FROM session')) norm(r['title'].toString()): (r['id'] as num).toInt(),
    };
    for (final s in data.sessions) {
      if (sessIds.containsKey(norm(s.title))) continue; // reaproveita sem alterar
      final filters = <Map<String, int>>[];
      for (final f in s.tagFilters) {
        filters.add({'tag_id': await tagId(f.tag), 'quantity': f.quantity});
      }
      // ⚠ confirme: time_limit em minutos (null = sem limite) e tag_filters como texto JSON
      final id = await txn.rawInsert(
        'INSERT INTO session (title, time_limit, total_q, tag_filters) VALUES (?, ?, ?, ?)',
        [s.title, s.timeLimitMinutes, s.totalQuestions, jsonEncode(filters)],
      );
      sessIds[norm(s.title)] = id;
      res.sessionsCreated++;
    }

    /* ----- pacotes e questões ----- */
    final pkgIds = <String, int>{
      for (final r in await txn.rawQuery('SELECT id, title FROM package')) norm(r['title'].toString()): (r['id'] as num).toInt(),
    };
    for (final p in data.packages) {
      var pid = pkgIds[norm(p.title)];
      if (pid == null) {
        final sid = p.sessionName == null ? null : sessIds[norm(p.sessionName!)];
        pid = await txn.rawInsert('INSERT INTO package (session_id, title) VALUES (?, ?)', [sid, p.title]);
        pkgIds[norm(p.title)] = pid;
        res.packagesCreated++;
      }

      // assinaturas das questões que o pacote já tem (evita duplicar ao reimportar)
      final seen = <String>{};
      for (final r in await txn.rawQuery('SELECT template_id, questions FROM question WHERE package_id = ?', [pid])) {
        final tid = (r['template_id'] as num).toInt();
        final def = tplById[tid];
        if (def == null) continue;
        seen.add('$tid|${QuestionCodec.enunciado(def, r['questions'].toString())}');
      }

      for (final q in p.questions) {
        final tid = tplIdByName[norm(q.templateName)]!;
        final def = tplById[tid]!;
        final sig = '$tid|${norm((q.values['enunciado'] ?? '').toString())}';
        if (!seen.add(sig)) {
          res.skippedQuestions++;
          continue;
        }
        final tg = q.tag == null ? null : await tagId(q.tag!);
        final qid = await txn.rawInsert(
          'INSERT INTO question (package_id, tag_id, template_id, questions) VALUES (?, ?, ?, ?)',
          [pid, tg, tid, QuestionCodec.encode(def, q.values, mediaMap)],
        );
        await txn.rawInsert('INSERT INTO state (question_id) VALUES (?)', [qid]);
        res.questions++;
      }
    }
    return res;
  }
}
