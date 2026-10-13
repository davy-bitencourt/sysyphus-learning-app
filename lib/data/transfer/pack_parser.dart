import 'dart:convert';

import 'pack_models.dart';

const Set<String> _types = {'text', 'image', 'audio', 'options', 'vof'};

final RegExp _headingRe = RegExp(r'^##\s+(.+?)\s*$');
final RegExp _headerRe = RegExp(r'^([A-Za-z_]+)\s*:\s*(.*)$');
final RegExp _optionRe = RegExp(r'^\s*[-*]\s+\[( |x|X)\]\s+(.+?)\s*$');
final RegExp _linkRe = RegExp(r'\]\(([^)]+)\)');
final RegExp _bareRe = RegExp(r'^\S+$');

/// Lê um pacote já descompactado (nome da entrada -> bytes) SEM tocar no banco.
/// Devolve o conteúdo e a lista de erros/avisos (cada um com arquivo e linha).
PackParseResult parsePack(Map<String, List<int>> files) => _PackParser(files).run();

class _Chunk {
  final int start; // número da primeira linha (1-based)
  final List<String> lines;
  const _Chunk(this.start, this.lines);
}

class _Section {
  final String label;
  final int line;
  final List<String> lines = [];
  _Section(this.label, this.line);
}

class _PackParser {
  _PackParser(this.files);

  final Map<String, List<int>> files;
  final List<PackIssue> _issues = [];
  final Set<String> _mediaUsed = {};
  final Map<String, PackTemplate> _templates = {};
  final Map<String, PackSession> _sessions = {};
  final List<PackPackage> _packages = [];
  final Set<String> _seenQuestions = {};
  final Set<String> _filesWithQuestions = {};

  void _err(String where, String message) =>
      _issues.add(PackIssue(PackIssueLevel.error, where, message));

  void _warn(String where, String message) =>
      _issues.add(PackIssue(PackIssueLevel.warning, where, message));

  String _decode(List<int> bytes) {
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    return text;
  }

  String _str(Object? v) => v is String ? v.trim() : '';

  Map<String, dynamic>? _readJson(String name, {bool required = true}) {
    final bytes = files[name];
    if (bytes == null) {
      if (required) _err(name, 'arquivo obrigatório não encontrado');
      return null;
    }
    try {
      final decoded = jsonDecode(_decode(bytes));
      if (decoded is Map<String, dynamic>) return decoded;
      _err(name, 'o JSON precisa ser um objeto { ... }');
    } catch (e) {
      _err(name, 'JSON inválido ($e)');
    }
    return null;
  }

  PackParseResult run() {
    for (final name in files.keys) {
      if (name.startsWith('/') || name.split('/').contains('..')) {
        _err(name, 'caminho inválido dentro do zip');
      }
    }

    final manifest = _readJson('manifest.json');
    if (manifest != null && (manifest['format'] != 'sysyphus-pack' || manifest['version'] != 1)) {
      _err('manifest.json', "esperado format 'sysyphus-pack' e version 1");
    }

    _parseTemplates();
    _parseSessions();
    _parsePackages();

    final unused = files.keys
        .where((n) => n.startsWith('media/') && !n.endsWith('/') && !_mediaUsed.contains(n))
        .toList()
      ..sort();
    for (final u in unused) {
      _warn(u, 'arquivo de mídia não usado por nenhuma questão');
    }

    return PackParseResult(
      data: PackData(
        templates: _templates.values.toList(),
        sessions: _sessions.values.toList(),
        packages: _packages,
      ),
      issues: _issues,
      mediaUsed: _mediaUsed,
    );
  }

  // ------------------------------------------------------------- templates

  void _parseTemplates() {
    final json = _readJson('templates.json');
    if (json == null) return;
    final list = json['templates'];
    if (list is! List) {
      _err('templates.json', "falta a lista 'templates'");
      return;
    }

    for (final raw in list) {
      if (raw is! Map) {
        _err('templates.json', 'cada template precisa ser um objeto');
        continue;
      }
      final name = _str(raw['name']);
      if (name.isEmpty) {
        _err('templates.json', 'template sem nome');
        continue;
      }
      final templateKey = normalizeText(name);
      if (_templates.containsKey(templateKey)) {
        _err('templates.json', "template '$name' repetido");
        continue;
      }

      final where = 'templates.json [$name]';
      final fields = <PackField>[];
      final labels = <String>{};
      var hasStatement = false;

      final rawFields = raw['fields'];
      for (final f in (rawFields is List ? rawFields : const <Object?>[])) {
        if (f is! Map) continue;
        final label = _str(f['label']);
        final type = f['type'];
        if (label.isEmpty) {
          _err(where, 'campo sem label');
          continue;
        }
        if (type is! String || !_types.contains(type)) {
          _err(where, "campo '$label': tipo '$type' inválido (use text, image, audio ou options)");
          continue;
        }
        final labelKey = normalizeText(label);
        if (!labels.add(labelKey)) {
          _err(where, "label '$label' repetido no mesmo template");
          continue;
        }

        var section = f['section'] is String ? f['section'] as String : 'question';
        if (section != 'question' && section != 'answer') {
          _err(where, "campo '$label': section deve ser question ou answer");
          continue;
        }

        final oc = f['optionCount'];
        final optionCount = oc is int ? oc : 4;
        final gradable = type == 'options' || type == 'vof';
        if (gradable) {
          if (optionCount < 2 || optionCount > 8) {
            _err(where, "campo '$label': optionCount deve ser de 2 a 8");
            continue;
          }
          if (section == 'answer') {
            _warn(where, "campo '$label' (alternativas) movido para antes de responder");
            section = 'question';
          }
        }

        if (labelKey == 'enunciado') {
          hasStatement = true;
          if (type != 'text') {
            _err(where, "o campo 'Enunciado' precisa ser do tipo text");
            continue;
          }
          section = 'question';
        }

        double? maxWidth;
        double? maxHeight;
        if (type == 'image') {
          final w = f['maxWidth'];
          final h = f['maxHeight'];
          if (w is num && w > 0) maxWidth = w.toDouble();
          if (h is num && h > 0) maxHeight = h.toDouble();
        }

        fields.add(PackField(
          label: label,
          type: type,
          section: section,
          optionCount: optionCount,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        ));
      }

      if (!hasStatement) {
        fields.insert(0, const PackField(label: 'Enunciado', type: 'text'));
        _warn(where, "sem campo 'Enunciado': ele será adicionado como primeiro campo");
      }
      _templates[templateKey] = PackTemplate(name: name, fields: fields);
    }
  }

  // -------------------------------------------------------------- sessions

  void _parseSessions() {
    final json = _readJson('sessions.json', required: false);
    if (json == null) return;
    final list = json['sessions'];
    if (list is! List) {
      _err('sessions.json', "falta a lista 'sessions'");
      return;
    }

    for (final raw in list) {
      if (raw is! Map) {
        _err('sessions.json', 'cada sessão precisa ser um objeto');
        continue;
      }
      final title = _str(raw['title']);
      if (title.isEmpty) {
        _err('sessions.json', 'sessão sem title');
        continue;
      }
      final key = normalizeText(title);
      if (_sessions.containsKey(key)) {
        _err('sessions.json', "sessão '$title' repetida");
        continue;
      }

      final where = 'sessions.json [$title]';
      var valid = true;

      // Tempo limite: timeLimitMinutes OU timeLimitSeconds (null = sem limite).
      int? limitSeconds;
      final tlMin = raw['timeLimitMinutes'];
      final tlSec = raw['timeLimitSeconds'];
      if (tlMin != null && tlSec != null) {
        _err(where, 'use timeLimitMinutes OU timeLimitSeconds, não os dois');
        valid = false;
      } else if (tlMin != null) {
        if (tlMin is int && tlMin >= 1) {
          limitSeconds = tlMin * 60;
        } else {
          _err(where, 'timeLimitMinutes deve ser null (sem limite) ou inteiro >= 1');
          valid = false;
        }
      } else if (tlSec != null) {
        if (tlSec is int && tlSec >= 1) {
          limitSeconds = tlSec;
        } else {
          _err(where, 'timeLimitSeconds deve ser inteiro >= 1');
          valid = false;
        }
      }

      var total = 0;
      final tq = raw['totalQuestions'];
      if (tq is int && tq >= 1) {
        total = tq;
      } else {
        _err(where, 'totalQuestions deve ser inteiro >= 1');
        valid = false;
      }

      final filters = <PackTagFilter>[];
      final seenTags = <String>{};
      var sum = 0;
      final rawFilters = raw['tagFilters'];
      if (rawFilters is List) {
        for (final f in rawFilters) {
          if (f is! Map) continue;
          final tag = _str(f['tag']).replaceFirst(RegExp(r'^#+'), '').trim();
          final q = f['quantity'];
          if (tag.isEmpty || q is! int || q < 1) {
            _err(where, 'cada filtro precisa de tag e quantity >= 1');
            valid = false;
            continue;
          }
          if (!seenTags.add(normalizeText(tag))) {
            _err(where, "tag '$tag' repetida nos filtros");
            valid = false;
            continue;
          }
          filters.add(PackTagFilter(tag, q));
          sum += q;
        }
      }
      if (valid && sum > total) {
        _err(where, 'a soma das quantidades por tag ($sum) passa do total da sessão ($total)');
        valid = false;
      }

      if (valid) {
        _sessions[key] = PackSession(
          title: title,
          timeLimitSeconds: limitSeconds,
          totalQuestions: total,
          tagFilters: filters,
        );
      }
    }
  }

  // -------------------------------------------------------------- packages

  void _parsePackages() {
    final slugSet = <String>{};
    for (final name in files.keys) {
      final parts = name.split('/');
      if (parts.length >= 3 && parts[0] == 'packages' && parts[1].isNotEmpty) {
        slugSet.add(parts[1]);
      }
    }
    final slugs = slugSet.toList()..sort();

    for (final slug in slugs) {
      final pj = _readJson('packages/$slug/package.json');
      if (pj == null) continue;

      final title = _str(pj['title']);
      if (title.isEmpty) {
        _err('packages/$slug/package.json', 'pacote sem title');
        continue;
      }
      final sessionTitle = _str(pj['session']).isEmpty ? null : _str(pj['session']);
      if (sessionTitle != null && !_sessions.containsKey(normalizeText(sessionTitle))) {
        _err('packages/$slug/package.json', "sessão '$sessionTitle' não existe em sessions.json");
      }

      final questions = <PackQuestion>[];
      final mdFiles = files.keys
          .where((n) => n.startsWith('packages/$slug/') && n.toLowerCase().endsWith('.md'))
          .toList()
        ..sort();
      for (final md in mdFiles) {
        questions.addAll(_parseMarkdown(md, title));
      }
      _packages.add(PackPackage(title: title, sessionTitle: sessionTitle, questions: questions));
    }
  }

  // -------------------------------------------------------------- markdown

  List<PackQuestion> _parseMarkdown(String fileName, String packageTitle) {
    final text = _decode(files[fileName]!).replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = text.split('\n');

    // 1) Blocos separados por linhas '---' (fora de cercas ```).
    final chunks = <_Chunk>[];
    var current = <String>[];
    var start = 1;
    var fence = false;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().startsWith('```')) fence = !fence;
      if (!fence && line.trim() == '---') {
        chunks.add(_Chunk(start, current));
        current = <String>[];
        start = i + 2;
      } else {
        current.add(line);
      }
    }
    chunks.add(_Chunk(start, current));

    // 2) Cada bloco é um padrão (só cabeçalho) ou uma questão (tem '## campo').
    final defaults = <String, String>{};
    final out = <PackQuestion>[];

    for (final chunk in chunks) {
      final header = <String, String>{};
      final sections = <_Section>[];
      _Section? sec;
      var inFence = false;

      var firstLine = chunk.start;
      for (var k = 0; k < chunk.lines.length; k++) {
        if (chunk.lines[k].trim().isNotEmpty) {
          firstLine = chunk.start + k;
          break;
        }
      }

      for (var k = 0; k < chunk.lines.length; k++) {
        final line = chunk.lines[k];
        final ln = chunk.start + k;
        if (line.trim().startsWith('```')) inFence = !inFence;

        final heading = inFence ? null : _headingRe.firstMatch(line);
        if (heading != null) {
          sec = _Section(heading.group(1)!, ln);
          sections.add(sec);
          continue;
        }

        if (sec == null) {
          if (line.trim().isEmpty) continue;
          final hm = _headerRe.firstMatch(line);
          if (hm == null) {
            _err('$fileName:$ln',
                "linha não reconhecida antes do primeiro '## campo': '${_cut(line.trim())}'");
            continue;
          }
          final key = hm.group(1)!.toLowerCase();
          if (key != 'template' && key != 'tag') {
            _err('$fileName:$ln', "chave '$key' desconhecida (use template ou tag)");
            continue;
          }
          header[key] = hm.group(2)!.trim();
        } else {
          sec.lines.add(line);
        }
      }

      if (sections.isEmpty) {
        if (header.isNotEmpty) {
          final changed = header.entries.any((e) => defaults.containsKey(e.key) && defaults[e.key] != e.value);
          if (changed || _filesWithQuestions.contains(fileName)) {
            _warn('$fileName:$firstLine',
                "bloco só com cabeçalho: ele REDEFINE o padrão (template/tag) das questões seguintes. "
                "Se queria configurar só a próxima questão, tire o '---' entre o cabeçalho e o primeiro '## campo'");
          }
          defaults.addAll(header);
        }
        continue;
      }

      final question = _buildQuestion(
        fileName: fileName,
        firstLine: firstLine,
        packageTitle: packageTitle,
        effective: {...defaults, ...header},
        sections: sections,
      );
      if (question != null) {
        out.add(question);
        _filesWithQuestions.add(fileName);
      }
    }
    return out;
  }

  String _cut(String s) => s.length <= 40 ? s : s.substring(0, 40);

  PackQuestion? _buildQuestion({
    required String fileName,
    required int firstLine,
    required String packageTitle,
    required Map<String, String> effective,
    required List<_Section> sections,
  }) {
    final where = '$fileName:$firstLine';
    final templateName = effective['template'] ?? '';
    if (templateName.isEmpty) {
      _err(where, "questão sem template (use 'template: Nome' na questão ou no topo do arquivo)");
      return null;
    }
    final template = _templates[normalizeText(templateName)];
    if (template == null) {
      _err(where, "template '$templateName' não existe em templates.json");
      return null;
    }

    final byLabel = <String, PackField>{
      for (final f in template.fields) normalizeText(f.label): f,
    };

    final values = <String, Object>{};
    final seenLabels = <String>{};
    var ok = true;

    for (final section in sections) {
      final key = normalizeText(section.label);
      final w = '$fileName:${section.line}';

      final field = byLabel[key];
      if (field == null) {
        final hint = _closest(key, byLabel.keys);
        final suggestion = hint == null ? '' : " (quis dizer '${byLabel[hint]!.label}'?)";
        _err(w, "campo '${section.label}' não existe no template '${template.name}'$suggestion");
        ok = false;
        continue;
      }
      if (!seenLabels.add(key)) {
        _err(w, "campo '${section.label}' repetido na mesma questão");
        ok = false;
        continue;
      }

      if (field.type == 'text') {
        values[key] = section.lines.map(packUnescapeLine).join('\n').trim();
      } else if (field.isMedia) {
        final path = _readMediaPath(section, field, w);
        if (path == null) {
          ok = false;
        } else {
          values[key] = path;
        }
      } else {
        final options = _readOptions(section, field, template.name, w);
        if (options == null) {
          ok = false;
        } else {
          values[key] = options;
        }
      }
    }

    for (final entry in byLabel.entries) {
      if (!seenLabels.contains(entry.key) && entry.value.isGradable) {
        _err(where, "falta o campo obrigatório '${entry.value.label}'");
        ok = false;
      }
    }

    final stmtValue = values['enunciado'];
    final statement = stmtValue is String ? stmtValue : '';
    if (!seenLabels.contains('enunciado') || statement.isEmpty) {
      _err(where, "falta o '## Enunciado' (ou ele está vazio)");
      ok = false;
    }
    if (!ok) return null;

    final dedupKey = '${normalizeText(packageTitle)}|${normalizeText(template.name)}|${normalizeText(statement)}';
    if (!_seenQuestions.add(dedupKey)) {
      _warn(where, 'enunciado repetido neste pacote (a segunda ocorrência será ignorada)');
    }

    return PackQuestion(
      packageTitle: packageTitle,
      templateName: template.name,
      tag: _readTag(effective['tag'] ?? '', where),
      statement: statement,
      values: values,
      sourceFile: fileName,
      line: firstLine,
    );
  }

  /// Uma tag só por questão (o banco guarda `tag_id` único). Aceita "#a",
  /// "a" ou "#a #b" (usa a primeira, com aviso).
  String? _readTag(String raw, String where) {
    final tokens = raw
        .split(RegExp(r'[,#]'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return null;
    if (tokens.length > 1) {
      _warn(where, "só uma tag por questão por enquanto: usando '${tokens.first}'");
    }
    return tokens.first;
  }

  String? _readMediaPath(_Section section, PackField field, String where) {
    final body = section.lines.join('\n').trim();
    if (body.isEmpty) return '';

    final link = _linkRe.firstMatch(body);
    var path = link != null ? link.group(1)!.trim() : (_bareRe.hasMatch(body) ? body : '');
    if (path.startsWith('./')) path = path.substring(2);
    if (path.isEmpty) {
      _err(where, 'esperado um caminho de arquivo (ex.: ![](media/foto.png))');
      return null;
    }

    final allowed = field.type == 'image' ? kPackImageExts : kPackAudioExts;
    if (!allowed.contains(packExtOf(path))) {
      _err(where, "'$path': extensão não aceita para ${field.type} (${(allowed.toList()..sort()).join(', ')})");
      return null;
    }
    if (!files.containsKey(path)) {
      _err(where, "arquivo '$path' não encontrado no zip");
      return null;
    }
    _mediaUsed.add(path);
    return path;
  }

  List<PackOption>? _readOptions(_Section section, PackField field, String templateName, String where) {
    final options = <PackOption>[];
    var valid = true;
    for (final line in section.lines) {
      if (line.trim().isEmpty) continue;
      final m = _optionRe.firstMatch(line);
      if (m == null) {
        _err(where, "alternativa inválida: '${_cut(line.trim())}' (use '- [ ] texto' ou '- [x] texto')");
        valid = false;
        continue;
      }
      options.add(PackOption(m.group(2)!, m.group(1)!.toLowerCase() == 'x'));
    }
    if (!valid) return null;
    if (options.length != field.optionCount) {
      _err(where, "o template '$templateName' espera ${field.optionCount} alternativas, a questão tem ${options.length}");
      return null;
    }
    if (!options.any((o) => o.correct)) {
      _warn(where, 'nenhuma alternativa marcada como correta');
    }
    return options;
  }

  /// Sugestão para rótulo digitado errado ("Enunciad" -> "enunciado").
  String? _closest(String key, Iterable<String> candidates) {
    String? best;
    var bestScore = 0.0;
    for (final c in candidates) {
      final score = _similarity(key, c);
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    return bestScore >= 0.6 ? best : null;
  }

  /// Similaridade simples (0 a 1) pela maior subsequência comum.
  double _similarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final dp = List.generate(a.length + 1, (_) => List<int>.filled(b.length + 1, 0));
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        dp[i][j] = a[i - 1] == b[j - 1]
            ? dp[i - 1][j - 1] + 1
            : (dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1]);
      }
    }
    return 2 * dp[a.length][b.length] / (a.length + b.length);
  }
}
