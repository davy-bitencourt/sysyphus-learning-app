import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'pack_models.dart';

const _imageExt = {'.png', '.jpg', '.jpeg', '.webp', '.gif'};
const _audioExt = {'.mp3', '.m4a', '.wav', '.ogg', '.aac'};

String _ext(String p) {
  final i = p.lastIndexOf('.');
  return i < 0 ? '' : p.substring(i).toLowerCase();
}

int _lev(String a, String b) {
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final c = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + c].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}

/// Lê o ZIP e valida tudo SEM gravar nada.
class PackReader {
  final PackReport r;
  final Map<String, TemplateDef> existingTemplates; // norm(nome) -> def
  final Set<String> existingSessions; // norm(título)
  final PackData data = PackData();
  final Map<String, Uint8List> _files = {};

  PackReader(this.r, {required this.existingTemplates, required this.existingSessions});

  PackData read(Uint8List bytes) {
    Archive zip;
    try {
      zip = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      r.errors.add('o arquivo não é um ZIP válido');
      return data;
    }
    for (final f in zip) {
      if (!f.isFile) continue;
      var n = f.name.replaceAll('\\', '/');
      while (n.startsWith('./')) {
        n = n.substring(2);
      }
      if (n.startsWith('__MACOSX/') || n.endsWith('.DS_Store')) continue;
      _files[n] = Uint8List.fromList(f.content as List<int>);
    }
    for (final e in _files.entries) {
      if (e.key.startsWith('media/')) data.media[e.key] = e.value;
    }

    _manifest();
    _templates();
    _sessions();
    _packages();

    for (final m in data.media.keys) {
      if (!data.usedMedia.contains(m)) r.warnings.add("arquivo '$m' não é usado por nenhuma questão");
    }
    return data;
  }

  dynamic _json(String name, {bool required = false}) {
    final b = _files[name];
    if (b == null) {
      if (required) r.errors.add('$name: arquivo não encontrado');
      return null;
    }
    try {
      var s = utf8.decode(b);
      if (s.startsWith('\uFEFF')) s = s.substring(1);
      return jsonDecode(s);
    } catch (e) {
      r.errors.add('$name: JSON inválido ($e)');
      return null;
    }
  }

  void _manifest() {
    final m = _json('manifest.json', required: true);
    if (m is! Map) return;
    if (m['format'] != 'sysyphus-pack') r.errors.add("manifest.json: 'format' deve ser 'sysyphus-pack'");
    if (m['version'] != 1) r.errors.add("manifest.json: versão '${m['version']}' não suportada (esperado 1)");
  }

  /* ---------------- templates.json ---------------- */
  void _templates() {
    final j = _json('templates.json');
    if (j == null) return;
    final list = (j is Map ? j['templates'] : null);
    if (list is! List) {
      r.errors.add("templates.json: esperado { \"templates\": [...] }");
      return;
    }
    final seen = <String>{};
    for (final t in list) {
      if (t is! Map) continue;
      final name = (t['name'] ?? '').toString().trim();
      final ctx = 'templates.json [$name]';
      if (name.isEmpty) {
        r.errors.add('templates.json: template sem nome');
        continue;
      }
      if (!seen.add(norm(name))) {
        r.errors.add("$ctx: nome de template repetido");
        continue;
      }
      final rawFields = t['fields'];
      if (rawFields is! List || rawFields.isEmpty) {
        r.errors.add("$ctx: 'fields' vazio ou ausente");
        continue;
      }
      final fields = <FieldDef>[];
      final labels = <String>{};
      var bad = false;
      for (final f in rawFields) {
        if (f is! Map) continue;
        final label = (f['label'] ?? '').toString().trim();
        final type = parseFieldType((f['type'] ?? '').toString());
        var section = (f['section'] ?? 'question').toString();
        if (label.isEmpty) {
          r.errors.add('$ctx: campo sem label');
          bad = true;
          continue;
        }
        if (!labels.add(norm(label))) {
          r.errors.add("$ctx: label '$label' repetido");
          bad = true;
          continue;
        }
        if (type == null) {
          r.errors.add("$ctx: campo '$label' tem type inválido '${f['type']}' (use text, image, audio ou options)");
          bad = true;
          continue;
        }
        if (section != 'question' && section != 'answer') {
          r.errors.add("$ctx: campo '$label' tem section inválida '$section'");
          bad = true;
          continue;
        }
        int? oc;
        if (type == FieldType.options) {
          oc = (f['optionCount'] as num?)?.toInt() ?? 4;
          if (oc < 2 || oc > 8) {
            r.errors.add("$ctx: campo '$label': optionCount deve estar entre 2 e 8");
            bad = true;
            continue;
          }
          if (section == 'answer') {
            section = 'question';
            r.warnings.add("$ctx: campo de opções '$label' movido para a seção 'question'");
          }
        }
        fields.add(FieldDef(
          label: label,
          type: type,
          section: section,
          optionCount: oc,
          maxWidth: type == FieldType.image ? (f['maxWidth'] as num?)?.toInt() : null,
          maxHeight: type == FieldType.image ? (f['maxHeight'] as num?)?.toInt() : null,
        ));
      }
      if (bad) continue;
      if (!fields.any((f) => norm(f.label) == 'enunciado' && f.type == FieldType.text)) {
        fields.insert(0, const FieldDef(label: 'Enunciado', type: FieldType.text));
        r.warnings.add("$ctx: faltava o campo 'Enunciado'; adicionado como primeiro campo");
      }
      data.templates.add(TemplateDef(name, fields));
    }
  }

  /* ---------------- sessions.json ---------------- */
  void _sessions() {
    final j = _json('sessions.json');
    if (j == null) return;
    final list = (j is Map ? j['sessions'] : null);
    if (list is! List) {
      r.errors.add("sessions.json: esperado { \"sessions\": [...] }");
      return;
    }
    final seen = <String>{};
    for (final s in list) {
      if (s is! Map) continue;
      final title = (s['title'] ?? '').toString().trim();
      final ctx = 'sessions.json [$title]';
      if (title.isEmpty) {
        r.errors.add('sessions.json: sessão sem título');
        continue;
      }
      if (!seen.add(norm(title))) {
        r.errors.add('$ctx: título repetido');
        continue;
      }
      final tl = s['timeLimitMinutes'];
      final total = s['totalQuestions'];
      var ok = true;
      if (tl != null && (tl is! int || tl < 1)) {
        r.errors.add("$ctx: 'timeLimitMinutes' deve ser null ou inteiro >= 1");
        ok = false;
      }
      if (total is! int || total < 1) {
        r.errors.add("$ctx: 'totalQuestions' deve ser inteiro >= 1");
        ok = false;
      }
      final filters = <({String tag, int quantity})>[];
      var sum = 0;
      for (final f in (s['tagFilters'] as List? ?? const [])) {
        final tag = (f is Map ? f['tag'] : null)?.toString().replaceFirst('#', '').trim() ?? '';
        final q = f is Map ? f['quantity'] : null;
        if (tag.isEmpty || q is! int || q < 1) {
          r.errors.add("$ctx: filtro de tag inválido (precisa de 'tag' e 'quantity' >= 1)");
          ok = false;
          continue;
        }
        sum += q;
        filters.add((tag: tag, quantity: q));
      }
      if (ok && sum > (total as int)) {
        r.errors.add('$ctx: a soma das quantidades por tag ($sum) passa do total da sessão ($total)');
        ok = false;
      }
      if (ok) data.sessions.add(SessionDef(title, tl as int?, total as int, filters));
    }
  }

  /* ---------------- packages/ ---------------- */
  Map<String, TemplateDef> get _allTemplates => {
        ...existingTemplates,
        for (final t in data.templates) norm(t.name): t,
      };

  void _packages() {
    final dirs = <String>{};
    for (final n in _files.keys) {
      final p = n.split('/');
      if (p.length >= 3 && p[0] == 'packages') dirs.add(p[1]);
    }
    if (dirs.isEmpty) r.warnings.add('o ZIP não tem nenhum pacote em packages/');
    final sessionNames = {
      ...existingSessions,
      for (final s in data.sessions) norm(s.title),
    };
    final titles = <String>{};

    for (final d in dirs.toList()..sort()) {
      final pj = _json('packages/$d/package.json');
      if (pj == null) {
        if (!_files.containsKey('packages/$d/package.json')) {
          r.errors.add('packages/$d: falta o package.json');
        }
        continue;
      }
      final title = (pj is Map ? pj['title'] : null)?.toString().trim() ?? '';
      if (title.isEmpty) {
        r.errors.add("packages/$d/package.json: 'title' obrigatório");
        continue;
      }
      if (!titles.add(norm(title))) {
        r.errors.add("packages/$d/package.json: pacote '$title' repetido");
        continue;
      }
      final sess = (pj as Map)['session']?.toString().trim();
      if (sess != null && sess.isNotEmpty && !sessionNames.contains(norm(sess))) {
        r.errors.add("packages/$d/package.json: sessão '$sess' não existe (sessions.json nem app)");
      }
      final pkg = PackageDef(title, (sess == null || sess.isEmpty) ? null : sess);
      final mds = _files.keys.where((n) => n.startsWith('packages/$d/') && n.toLowerCase().endsWith('.md')).toList()..sort();
      for (final md in mds) {
        _parseMd(md, pkg);
      }
      data.packages.add(pkg);
    }
  }

  /* ---------------- .md ---------------- */
  static final _headerRe = RegExp(r'^([A-Za-z_]+)\s*:\s*(.*)$');
  static final _sectionRe = RegExp(r'^##\s+(.+?)\s*$');
  static final _optRe = RegExp(r'^[-*]\s*\[( |x|X)\]\s*(.*)$');

  void _parseMd(String file, PackageDef pkg) {
    var text = utf8.decode(_files[file]!, allowMalformed: true);
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    final lines = text.split(RegExp(r'\r?\n'));

    // 1) divide em blocos por '---' (fora de ```)
    final blocks = <({int start, List<String> lines})>[];
    var cur = <String>[];
    var start = 1;
    var fence = false;
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (l.trimLeft().startsWith('```')) {
        fence = !fence;
      } else if (!fence && l.trim() == '---') {
        blocks.add((start: start, lines: cur));
        cur = [];
        start = i + 2;
        continue;
      }
      cur.add(l);
    }
    blocks.add((start: start, lines: cur));

    String? defTemplate;
    String? defTag;
    var first = true;

    for (final b in blocks) {
      final header = <String, String>{};
      final sections = <({int line, String label, List<String> body})>[];
      var f = false;
      for (var i = 0; i < b.lines.length; i++) {
        final l = b.lines[i];
        final ln = b.start + i;
        if (l.trimLeft().startsWith('```')) f = !f;
        final sm = f ? null : _sectionRe.firstMatch(l);
        if (sm != null) {
          sections.add((line: ln, label: sm.group(1)!, body: []));
        } else if (sections.isNotEmpty) {
          sections.last.body.add(l);
        } else if (l.trim().isEmpty) {
          continue;
        } else {
          final hm = _headerRe.firstMatch(l.trim());
          if (hm == null) {
            r.errors.add("$file:$ln: texto fora de uma seção '## campo'");
            continue;
          }
          final key = hm.group(1)!.toLowerCase();
          if (key != 'template' && key != 'tag') {
            r.errors.add("$file:$ln: chave de cabeçalho '${hm.group(1)}' não aceita (use template ou tag)");
            continue;
          }
          header[key] = hm.group(2)!.trim();
        }
      }

      // bloco só de cabeçalho: define o padrão
      if (sections.isEmpty) {
        if (header.isEmpty) continue;
        if (!first) {
          r.warnings.add("$file:${b.start}: bloco só com cabeçalho: ele REDEFINE o padrão (template/tag) das questões seguintes. "
              "Se queria configurar só a próxima questão, tire o '---' entre o cabeçalho e o primeiro '## campo'");
        }
        if (header.containsKey('template')) defTemplate = header['template']!.isEmpty ? null : header['template'];
        if (header.containsKey('tag')) defTag = _firstTag(header['tag']!, file, b.start);
        first = false;
        continue;
      }
      first = false;

      final tplName = header.containsKey('template') ? header['template']! : (defTemplate ?? '');
      final tag = header.containsKey('tag') ? _firstTag(header['tag']!, file, b.start) : defTag;
      final qLine = sections.first.line;

      if (tplName.isEmpty) {
        r.errors.add("$file:$qLine: questão sem template (defina 'template:' no cabeçalho)");
        continue;
      }
      final tpl = _allTemplates[norm(tplName)];
      if (tpl == null) {
        r.errors.add("$file:$qLine: template '$tplName' não existe (nem em templates.json nem no app)");
        continue;
      }

      final values = <String, dynamic>{};
      var ok = true;
      for (final s in sections) {
        final fd = tpl.fieldByLabel(s.label);
        if (fd == null) {
          var sug = '';
          for (final cand in tpl.fields) {
            final a = norm(cand.label), c = norm(s.label);
            if (_lev(a, c) <= 2 || a.startsWith(c) || c.startsWith(a)) {
              sug = " (quis dizer '${cand.label}'?)";
              break;
            }
          }
          r.errors.add("$file:${s.line}: campo '${s.label}' não existe no template '${tpl.name}'$sug");
          ok = false;
          continue;
        }
        final key = norm(fd.label);
        if (values.containsKey(key)) {
          r.errors.add("$file:${s.line}: campo '${fd.label}' repetido na mesma questão");
          ok = false;
          continue;
        }
        final v = _value(fd, s.body, file, s.line);
        if (v == null) {
          ok = false;
        } else {
          values[key] = v;
        }
      }
      for (final fd in tpl.fields) {
        final key = norm(fd.label);
        final needed = key == 'enunciado' || fd.type == FieldType.options;
        final v = values[key];
        if (needed && (v == null || (v is String && v.isEmpty))) {
          if (!sections.any((s) => norm(s.label) == key)) {
            r.errors.add("$file:$qLine: falta o campo obrigatório '${fd.label}'");
          } else if (ok) {
            r.errors.add("$file:$qLine: o campo '${fd.label}' está vazio");
          }
          ok = false;
        }
      }
      if (ok) pkg.questions.add(ParsedQuestion(file, qLine, tpl.name, tag, values));
    }
  }

  String? _firstTag(String raw, String file, int line) {
    final tags = raw.split(RegExp(r'[,;]')).map((t) => t.trim().replaceFirst(RegExp(r'^#+'), '').trim()).where((t) => t.isNotEmpty).toList();
    if (tags.isEmpty) return null;
    if (tags.length > 1) {
      r.warnings.add("$file:$line: o app aceita uma tag por questão; usando só '${tags.first}'");
    }
    return tags.first;
  }

  /// null = erro já registrado.
  dynamic _value(FieldDef fd, List<String> body, String file, int line) {
    final raw = body.join('\n').trim();
    switch (fd.type) {
      case FieldType.text:
        // texto protegido por cerca ``` (usado na exportação) tem a cerca removida
        final ls = raw.split('\n');
        if (ls.length >= 2 && ls.first.trim() == '```' && ls.last.trim() == '```') {
          return ls.sublist(1, ls.length - 1).join('\n');
        }
        return raw;

      case FieldType.image:
      case FieldType.audio:
        if (raw.isEmpty) return '';
        if (raw.contains('\n')) {
          r.errors.add("$file:$line: o campo '${fd.label}' aceita um único arquivo");
          return null;
        }
        final re = fd.type == FieldType.image ? RegExp(r'^!\[[^\]]*\]\(([^)]+)\)$') : RegExp(r'^!?\[[^\]]*\]\(([^)]+)\)$');
        final m = re.firstMatch(raw);
        var p = (m != null ? m.group(1)! : raw).trim().replaceAll('\\', '/');
        if (p.startsWith('<') && p.endsWith('>')) p = p.substring(1, p.length - 1);
        while (p.startsWith('./')) {
          p = p.substring(2);
        }
        final ext = _ext(p);
        final exts = fd.type == FieldType.image ? _imageExt : _audioExt;
        if (!exts.contains(ext)) {
          r.errors.add("$file:$line: '$p' não é ${fd.type == FieldType.image ? 'uma imagem' : 'um áudio'} suportado (${exts.join(' ')})");
          return null;
        }
        if (!_files.containsKey(p)) {
          r.errors.add("$file:$line: arquivo '$p' não encontrado no zip");
          return null;
        }
        data.usedMedia.add(p);
        return p;

      case FieldType.options:
        final opts = <Map<String, dynamic>>[];
        for (final l in body) {
          if (l.trim().isEmpty) continue;
          final m = _optRe.firstMatch(l.trim());
          if (m == null) {
            r.errors.add("$file:$line: alternativa inválida '${l.trim()}' (use '- [ ] texto' ou '- [x] texto')");
            return null;
          }
          opts.add({'text': m.group(2)!.trim(), 'correct': m.group(1)!.toLowerCase() == 'x'});
        }
        if (opts.length != fd.optionCount) {
          r.errors.add("$file:$line: o campo '${fd.label}' espera ${fd.optionCount} alternativas, a questão tem ${opts.length}");
          return null;
        }
        if (!opts.any((o) => o['correct'] == true)) {
          r.warnings.add("$file:$line: nenhuma alternativa marcada como correta em '${fd.label}'");
        }
        return opts;
    }
  }
}
