import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../DAO/session_dao.dart';
import '../database_helper.dart';
import '../models/field_model.dart';
import 'pack_models.dart';

class ExportResult {
  final Uint8List bytes;
  final int packages;
  final int questions;
  final int templates;
  final int sessions;
  final int mediaFiles;
  final List<String> warnings;
  const ExportResult({
    required this.bytes,
    required this.packages,
    required this.questions,
    required this.templates,
    required this.sessions,
    required this.mediaFiles,
    required this.warnings,
  });
}

String _uniqueName(String base, Set<String> taken) {
  final clean = base.trim().isEmpty ? 'Sem nome' : base.trim();
  var candidate = clean;
  var n = 2;
  while (taken.contains(normalizeText(candidate))) {
    candidate = '$clean ($n)';
    n++;
  }
  taken.add(normalizeText(candidate));
  return candidate;
}

String _slug(String title) {
  final s = normalizeText(title).replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return s.isEmpty ? 'pacote' : s;
}

/// Rótulos únicos dentro do template (o formato exige). O Enunciado sempre
/// fica com o nome "Enunciado".
Map<String, String> _uniqueLabels(TemplateModel t) {
  final taken = <String>{};
  final out = <String, String>{};
  for (final f in t.fields) {
    if (f.isStatement) {
      out[f.id] = 'Enunciado';
      taken.add('enunciado');
    }
  }
  for (final f in t.fields) {
    if (f.isStatement) continue;
    out[f.id] = _uniqueName(f.label.trim().isEmpty ? 'Campo' : f.label, taken);
  }
  return out;
}

/// Gera o .zip com templates, sessões, pacotes, questões (.md) e mídias.
/// [packageIds] null = exporta tudo; senão só esses pacotes (e o que eles usam).
Future<ExportResult> buildExport({Set<int>? packageIds}) async {
  final db = await DatabaseHelper.instance.database;
  final warnings = <String>[];
  final archive = Archive();

  void addBytes(String name, List<int> bytes) {
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  void addText(String name, String text) => addBytes(name, utf8.encode(text));
  String pretty(Object json) => const JsonEncoder.withIndent('  ').convert(json);

  // ---- leitura do banco ----
  final templateModels = <int, TemplateModel>{};
  for (final r in await db.rawQuery('SELECT id, template FROM templates ORDER BY id')) {
    try {
      final id = r['id'] as int;
      templateModels[id] = TemplateModel.fromJson(id, r['template'] as String);
    } catch (_) {
      // template ilegível: fica de fora
    }
  }

  final tagTitles = <int, String>{};
  for (final r in await db.rawQuery('SELECT id, title FROM tag')) {
    tagTitles[r['id'] as int] = (r['title'] as String?) ?? '';
  }

  final sessionRows = await db.rawQuery(
    'SELECT id, title, time_limit, total_q, tag_filters FROM session ORDER BY id',
  );
  final allPackages = await db.rawQuery('SELECT id, session_id, title FROM package ORDER BY id');
  final packages = allPackages.where((r) => packageIds == null || packageIds.contains(r['id'] as int)).toList();

  final questionsByPackage = <int, List<Map<String, Object?>>>{};
  final usedTemplateIds = <int>{};
  final usedSessionIds = <int>{};
  for (final p in packages) {
    final pid = p['id'] as int;
    final rows = await db.rawQuery(
      'SELECT id, template_id, tag_id, questions FROM question WHERE package_id = ? ORDER BY id',
      [pid],
    );
    questionsByPackage[pid] = rows;
    for (final q in rows) {
      final tid = q['template_id'];
      if (tid is int) usedTemplateIds.add(tid);
    }
    final sid = p['session_id'];
    if (sid is int) usedSessionIds.add(sid);
  }

  // ---- templates ----
  final exportTemplateIds = (packageIds == null ? templateModels.keys.toSet() : usedTemplateIds.intersection(templateModels.keys.toSet())).toList()
    ..sort();
  final templateNames = <int, String>{};
  final templateLabels = <int, Map<String, String>>{};
  final takenTemplateNames = <String>{};
  final templatesJson = <Map<String, Object?>>[];

  for (final id in exportTemplateIds) {
    final t = templateModels[id]!;
    final name = _uniqueName(t.name, takenTemplateNames);
    final labels = _uniqueLabels(t);
    templateNames[id] = name;
    templateLabels[id] = labels;

    templatesJson.add({
      'name': name,
      'fields': [
        for (final f in t.fields)
          {
            'label': labels[f.id],
            'type': f.type,
            'section': f.section,
            if (FieldType.isGradable(f.type)) 'optionCount': f.optionCount,
            if (f.type == FieldType.image && f.maxWidth != null) 'maxWidth': f.maxWidth,
            if (f.type == FieldType.image && f.maxHeight != null) 'maxHeight': f.maxHeight,
          },
      ],
    });
  }

  // ---- sessões ----
  final sessionTitles = <int, String>{};
  final takenSessionTitles = <String>{};
  final sessionsJson = <Map<String, Object?>>[];
  for (final r in sessionRows) {
    final id = r['id'] as int;
    if (packageIds != null && !usedSessionIds.contains(id)) continue;

    final title = _uniqueName((r['title'] as String?) ?? 'Sessão $id', takenSessionTitles);
    sessionTitles[id] = title;

    final filters = <Map<String, Object?>>[];
    var sum = 0;
    for (final f in SessionDao.parseTagFilters(r['tag_filters'] as String?)) {
      final tagName = tagTitles[f['tag_id']];
      if (tagName == null || tagName.isEmpty) continue;
      filters.add({'tag': tagName, 'quantity': f['quantity']});
      sum += f['quantity']!;
    }
    var total = (r['total_q'] as num?)?.toInt();
    if (total == null || total < 1) {
      total = sum > 0 ? sum : 20;
      warnings.add("A sessão '$title' não tinha total de questões: exportada com $total.");
    }
    if (sum > total) total = sum;

    final limitSeconds = SessionDao.parseTimeLimitSeconds(r['time_limit'] as String?);

    sessionsJson.add({
      'title': title,
      // minutos quando o tempo é redondo; segundos quando não é.
      if (limitSeconds == null)
        'timeLimitMinutes': null
      else if (limitSeconds % 60 == 0)
        'timeLimitMinutes': limitSeconds ~/ 60
      else
        'timeLimitSeconds': limitSeconds,
      'totalQuestions': total,
      'tagFilters': filters,
    });
  }

  // ---- mídias ----
  final mediaNames = <String, String>{}; // caminho local -> nome no zip
  var imageCount = 0;
  var audioCount = 0;

  Future<String?> addMedia(String localPath, bool isImage) async {
    final already = mediaNames[localPath];
    if (already != null) return already;

    final file = File(localPath);
    if (!await file.exists()) {
      warnings.add('Arquivo de mídia não encontrado (ignorado): $localPath');
      return null;
    }
    final ext = packExtOf(localPath);
    final allowed = isImage ? kPackImageExts : kPackAudioExts;
    if (!allowed.contains(ext)) {
      warnings.add('Extensão de mídia não suportada (ignorada): $localPath');
      return null;
    }
    final name = isImage ? 'media/img_${++imageCount}$ext' : 'media/aud_${++audioCount}$ext';
    addBytes(name, await file.readAsBytes());
    mediaNames[localPath] = name;
    return name;
  }

  // ---- pacotes e questões ----
  final takenSlugs = <String>{};
  final takenPackageTitles = <String>{};
  var questionTotal = 0;

  for (final p in packages) {
    final pid = p['id'] as int;
    final title = _uniqueName((p['title'] as String?) ?? 'Pacote $pid', takenPackageTitles);

    var slug = _slug(title);
    var slugN = 2;
    while (!takenSlugs.add(slug)) {
      slug = '${_slug(title)}-$slugN';
      slugN++;
    }

    final sessionId = p['session_id'];
    final sessionTitle = sessionId is int ? sessionTitles[sessionId] : null;
    addText('packages/$slug/package.json', pretty({'title': title, 'session': sessionTitle}));

    final blocks = <String>[];
    for (final q in questionsByPackage[pid] ?? const <Map<String, Object?>>[]) {
      final tid = q['template_id'];
      final template = tid is int ? templateModels[tid] : null;
      if (template == null || tid is! int || !templateNames.containsKey(tid)) {
        warnings.add("Questão ${q['id']} ignorada: o template dela não existe mais.");
        continue;
      }

      Map<String, dynamic> values;
      try {
        final decoded = jsonDecode((q['questions'] as String?) ?? '{}');
        values = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      } catch (_) {
        warnings.add('Questão ${q['id']} ignorada: conteúdo ilegível.');
        continue;
      }

      final labels = templateLabels[tid]!;
      final b = StringBuffer();
      b.writeln('template: ${templateNames[tid]}');
      final tagId = q['tag_id'];
      final tagName = tagId is int ? tagTitles[tagId] : null;
      if (tagName != null && tagName.trim().isNotEmpty) {
        b.writeln('tag: ${tagName.replaceAll(RegExp(r'[,#]'), ' ').trim()}');
      }
      b.writeln();

      for (final f in template.fields) {
        final v = values[f.id];
        b.writeln('## ${labels[f.id]}');

        if (f.type == FieldType.text) {
          var text = v is String ? v : '';
          if (f.isStatement && text.trim().isEmpty) {
            text = '(sem enunciado)';
            warnings.add('Questão ${q['id']} não tinha enunciado: exportada como "(sem enunciado)".');
          }
          final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
          if (normalized.isNotEmpty) {
            b.writeln(normalized.split('\n').map(packEscapeLine).join('\n'));
          }
        } else if (f.type == FieldType.image || f.type == FieldType.audio) {
          if (v is String && v.isNotEmpty) {
            final isImage = f.type == FieldType.image;
            final name = await addMedia(v, isImage);
            if (name != null) b.writeln(isImage ? '![]($name)' : '[]($name)');
          }
        } else if (FieldType.isGradable(f.type)) {
          final raw = v is List ? v : const <Object?>[];
          final options = <PackOption>[];
          for (final o in raw) {
            if (o is Map) {
              final text = (o['text'] is String ? o['text'] as String : '').replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();
              options.add(PackOption(text.isEmpty ? '(vazio)' : text, o['correct'] == true));
            }
          }
          if (options.length != f.optionCount) {
            warnings.add('Questão ${q['id']}: ${options.length} alternativas em "${labels[f.id]}", o template pede ${f.optionCount}; ajustado.');
            while (options.length < f.optionCount) {
              options.add(const PackOption('(vazio)', false));
            }
            if (options.length > f.optionCount) options.removeRange(f.optionCount, options.length);
          }
          for (final o in options) {
            b.writeln('- [${o.correct ? 'x' : ' '}] ${o.text}');
          }
        }
        b.writeln();
      }
      blocks.add(b.toString());
      questionTotal++;
    }
    addText('packages/$slug/questoes.md', blocks.join('---\n'));
  }

  // ---- arquivos de topo ----
  final stamp = DateTime.now().toIso8601String().substring(0, 10);
  addText('manifest.json', pretty({'format': 'sysyphus-pack', 'version': 1, 'name': 'Sysyphus $stamp'}));
  addText('templates.json', pretty({'templates': templatesJson}));
  if (sessionsJson.isNotEmpty) addText('sessions.json', pretty({'sessions': sessionsJson}));

  final bytes = ZipEncoder().encodeBytes(archive);

  return ExportResult(
    bytes: bytes,
    packages: packages.length,
    questions: questionTotal,
    templates: templatesJson.length,
    sessions: sessionsJson.length,
    mediaFiles: mediaNames.length,
    warnings: warnings,
  );
}
