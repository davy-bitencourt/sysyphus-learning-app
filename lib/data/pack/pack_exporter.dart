import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../database_helper.dart';
import 'pack_models.dart';
import 'question_codec.dart';

class ExportResult {
  final Uint8List bytes;
  final List<String> warnings;
  final String summary;
  ExportResult(this.bytes, this.warnings, this.summary);
}

class PackExporter {
  /// [packageIds] = null exporta tudo.
  static Future<ExportResult> build({List<int>? packageIds}) async {
    final db = await DatabaseHelper.instance.database;
    final warnings = <String>[];
    final zip = Archive();

    void addText(String path, String content) {
      final b = utf8.encode(content);
      zip.addFile(ArchiveFile(path, b.length, b));
    }

    String uniq(String base, Set<String> used) {
      var n = base, i = 2;
      while (!used.add(norm(n))) {
        n = '$base ($i)';
        i++;
      }
      return n;
    }

    /* tags */
    final tagName = {
      for (final r in await db.rawQuery('SELECT id, title FROM tag')) (r['id'] as num).toInt(): r['title'].toString().replaceAll(RegExp(r'[,;\n]'), ' ').trim(),
    };

    /* templates (nomes únicos) */
    final tplDefs = <int, TemplateDef>{};
    final tplNames = <int, String>{};
    final usedTplNames = <String>{};
    for (final r in await db.rawQuery('SELECT id, template FROM templates ORDER BY id')) {
      try {
        final d = TemplateDef.fromDbJson(jsonDecode(r['template'] as String) as Map<String, dynamic>);
        final id = (r['id'] as num).toInt();
        tplDefs[id] = d;
        tplNames[id] = uniq(d.name.isEmpty ? 'Template $id' : d.name, usedTplNames);
      } catch (_) {}
    }

    /* sessões (títulos únicos) */
    final sessRows = await db.rawQuery('SELECT id, title, time_limit, total_q, tag_filters FROM session ORDER BY id');
    final sessNames = <int, String>{};
    final usedSess = <String>{};
    final sessionsJson = <Map<String, dynamic>>[];
    for (final s in sessRows) {
      final id = (s['id'] as num).toInt();
      final name = uniq(s['title'].toString(), usedSess);
      sessNames[id] = name;
      final filters = <Map<String, dynamic>>[];
      try {
        for (final f in (jsonDecode((s['tag_filters'] ?? '[]').toString()) as List)) {
          final t = tagName[(f['tag_id'] as num).toInt()];
          if (t != null) filters.add({'tag': t, 'quantity': (f['quantity'] as num).toInt()});
        }
      } catch (_) {}
      sessionsJson.add({
        'title': name,
        'timeLimitMinutes': (s['time_limit'] as num?)?.toInt(),
        'totalQuestions': (s['total_q'] as num).toInt(),
        'tagFilters': filters,
      });
    }

    /* pacotes */
    var pkgRows = await db.rawQuery('SELECT id, session_id, title FROM package ORDER BY id');
    if (packageIds != null) {
      pkgRows = pkgRows.where((p) => packageIds.contains((p['id'] as num).toInt())).toList();
    }

    final mediaOut = <String, String>{}; // caminho local -> media/xxx
    final usedFolders = <String>{};
    final usedTplExport = <int>{};
    final usedSessExport = <int>{};
    var qCount = 0;

    String mediaFor(String local) {
      return mediaOut.putIfAbsent(local, () {
        final base = local.split(RegExp(r'[\\/]')).last;
        return 'media/${mediaOut.length + 1}_$base';
      });
    }

    for (final p in pkgRows) {
      final pid = (p['id'] as num).toInt();
      final title = p['title'].toString();
      final sid = (p['session_id'] as num?)?.toInt();
      if (sid != null && sessNames.containsKey(sid)) usedSessExport.add(sid);
      final slug = norm(title).replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
      var folder = slug.isEmpty ? 'pacote-$pid' : slug;
      var k = 2;
      while (!usedFolders.add(folder)) {
        folder = '${slug.isEmpty ? 'pacote' : slug}-${k++}';
      }

      addText('packages/$folder/package.json',
          const JsonEncoder.withIndent('  ').convert({'title': title, 'session': sid == null ? null : sessNames[sid]}));

      final qs = await db.rawQuery('SELECT id, tag_id, template_id, questions FROM question WHERE package_id = ? ORDER BY id', [pid]);
      final md = StringBuffer();
      var first = true;
      for (final q in qs) {
        final tid = (q['template_id'] as num).toInt();
        final def = tplDefs[tid];
        if (def == null) {
          warnings.add('questão ${q['id']} ignorada: template $tid não encontrado');
          continue;
        }
        usedTplExport.add(tid);
        final values = QuestionCodec.decode(def, q['questions'].toString());
        if (!first) md.writeln('---');
        first = false;
        md.writeln('template: ${tplNames[tid]}');
        final tag = tagName[(q['tag_id'] as num?)?.toInt()];
        md.writeln('tag: ${tag ?? ''}');
        md.writeln();

        for (final f in def.fields) {
          final v = values[f];
          if (v == null) continue;
          switch (f.type) {
            case FieldType.text:
              final s = v.toString();
              if (s.trim().isEmpty) continue;
              final risky = s.split('\n').any((l) => l.trim() == '---' || l.startsWith('##') || l.trimLeft().startsWith('```'));
              md.writeln('## ${f.label}');
              md.writeln(risky ? '```\n$s\n```' : s);
              md.writeln();
              break;
            case FieldType.image:
            case FieldType.audio:
              final local = v.toString();
              if (local.isEmpty) continue;
              if (!File(local).existsSync()) {
                warnings.add("questão ${q['id']}: arquivo '$local' não existe mais; campo '${f.label}' omitido");
                continue;
              }
              final rel = mediaFor(local);
              md.writeln('## ${f.label}');
              md.writeln(f.type == FieldType.image ? '![]($rel)' : '[]($rel)');
              md.writeln();
              break;
            case FieldType.options:
              md.writeln('## ${f.label}');
              for (final o in (v as List)) {
                final text = (o['text'] ?? '').toString().replaceAll(RegExp(r'\s*\n\s*'), ' ');
                md.writeln('- [${o['correct'] == true ? 'x' : ' '}] $text');
              }
              md.writeln();
              break;
          }
        }
        qCount++;
      }
      addText('packages/$folder/questoes.md', md.toString());
    }

    /* templates.json: só os usados */
    final tplJson = [
      for (final id in usedTplExport)
        {
          'name': tplNames[id],
          'fields': [
            for (final f in tplDefs[id]!.fields)
              {
                'label': f.label,
                'type': f.type.name,
                'section': f.section,
                if (f.optionCount != null) 'optionCount': f.optionCount,
                if (f.maxWidth != null) 'maxWidth': f.maxWidth,
                if (f.maxHeight != null) 'maxHeight': f.maxHeight,
              },
          ],
        }
    ];
    const enc = JsonEncoder.withIndent('  ');
    addText('manifest.json', enc.convert({'format': 'sysyphus-pack', 'version': 1, 'name': 'Sysyphus export ${DateTime.now().toIso8601String().substring(0, 10)}'}));
    addText('templates.json', enc.convert({'templates': tplJson}));
    // sessões: com exportação parcial, só as dos pacotes exportados
    final sessOut = packageIds == null
        ? sessionsJson
        : [for (final s in sessionsJson) if (usedSessExport.any((id) => sessNames[id] == s['title'])) s];
    addText('sessions.json', enc.convert({'sessions': sessOut}));

    for (final e in mediaOut.entries) {
      final bytes = File(e.key).readAsBytesSync();
      zip.addFile(ArchiveFile(e.value, bytes.length, bytes));
    }

    final out = Uint8List.fromList(ZipEncoder().encode(zip)!);
    return ExportResult(out, warnings,
        '$qCount questões, ${tplJson.length} templates, ${pkgRows.length} pacotes, ${sessOut.length} sessões, ${mediaOut.length} mídias');
  }
}
