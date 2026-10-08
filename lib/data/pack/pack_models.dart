import 'dart:typed_data';

/* ---------- normalização: sem maiúsculas, sem acentos, espaços colapsados ---------- */
const _from = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
const _to = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';

String norm(String s) {
  final b = StringBuffer();
  for (final r in s.trim().runes) {
    final c = String.fromCharCode(r);
    final i = _from.indexOf(c);
    b.write(i >= 0 ? _to[i] : c);
  }
  return b.toString().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

/* ---------- relatório ---------- */
class PackReport {
  final List<String> errors = [];
  final List<String> warnings = [];
  bool get ok => errors.isEmpty;
}

/* ---------- templates ---------- */
enum FieldType { text, image, audio, options }

FieldType? parseFieldType(String s) {
  for (final t in FieldType.values) {
    if (t.name == s) return t;
  }
  return null;
}

class FieldDef {
  final String id; // '' quando vem do ZIP (o app gera na importação)
  final String label;
  final FieldType type;
  final String section; // 'question' | 'answer'
  final int? optionCount;
  final int? maxWidth;
  final int? maxHeight;

  const FieldDef({
    this.id = '',
    required this.label,
    required this.type,
    this.section = 'question',
    this.optionCount,
    this.maxWidth,
    this.maxHeight,
  });

  FieldDef copyWith({String? id, String? section}) => FieldDef(
        id: id ?? this.id,
        label: label,
        type: type,
        section: section ?? this.section,
        optionCount: optionCount,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );

  /* ⚠ formato interno do campo no banco: ajuste aqui se o seu for diferente */
  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'type': type.name,
        'section': section,
        if (optionCount != null) 'optionCount': optionCount,
        if (maxWidth != null) 'maxWidth': maxWidth,
        if (maxHeight != null) 'maxHeight': maxHeight,
      };

  static FieldDef fromJson(Map m) => FieldDef(
        id: (m['id'] ?? '').toString(),
        label: (m['label'] ?? '').toString(),
        type: parseFieldType((m['type'] ?? 'text').toString()) ?? FieldType.text,
        section: (m['section'] ?? 'question').toString(),
        optionCount: (m['optionCount'] as num?)?.toInt(),
        maxWidth: (m['maxWidth'] as num?)?.toInt(),
        maxHeight: (m['maxHeight'] as num?)?.toInt(),
      );

  bool sameShape(FieldDef o) =>
      norm(label) == norm(o.label) &&
      type == o.type &&
      section == o.section &&
      optionCount == o.optionCount &&
      maxWidth == o.maxWidth &&
      maxHeight == o.maxHeight;
}

class TemplateDef {
  final String name;
  final List<FieldDef> fields;
  const TemplateDef(this.name, this.fields);

  bool sameShape(TemplateDef o) {
    if (fields.length != o.fields.length) return false;
    for (var i = 0; i < fields.length; i++) {
      if (!fields[i].sameShape(o.fields[i])) return false;
    }
    return true;
  }

  TemplateDef renamed(String n) => TemplateDef(n, fields);

  /// Gera ids novos para os campos (na importação).
  TemplateDef withNewIds() {
    final base = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return TemplateDef(name, [
      for (var i = 0; i < fields.length; i++) fields[i].copyWith(id: 'f$base$i'),
    ]);
  }

  FieldDef? fieldByLabel(String label) {
    final k = norm(label);
    for (final f in fields) {
      if (norm(f.label) == k) return f;
    }
    return null;
  }

  /* ⚠ formato do JSON da coluna templates.template */
  Map<String, dynamic> toDbJson() => {
        'name': name,
        'fields': [for (final f in fields) f.toJson()],
      };

  static TemplateDef fromDbJson(Map<String, dynamic> m) => TemplateDef(
        (m['name'] ?? '').toString(),
        [
          for (final f in (m['fields'] as List? ?? const []))
            FieldDef.fromJson(f as Map),
        ],
      );
}

/* ---------- sessões / pacotes / questões lidas do ZIP ---------- */
class SessionDef {
  final String title;
  final int? timeLimitMinutes;
  final int totalQuestions;
  final List<({String tag, int quantity})> tagFilters;
  const SessionDef(this.title, this.timeLimitMinutes, this.totalQuestions, this.tagFilters);
}

class ParsedQuestion {
  final String file;
  final int line;
  final String templateName;
  final String? tag;

  /// rótulo normalizado -> valor (String | List<{text, correct}>)
  final Map<String, dynamic> values;
  ParsedQuestion(this.file, this.line, this.templateName, this.tag, this.values);
}

class PackageDef {
  final String title;
  final String? sessionName;
  final List<ParsedQuestion> questions = [];
  PackageDef(this.title, this.sessionName);
}

class PackData {
  final List<TemplateDef> templates = [];
  final List<SessionDef> sessions = [];
  final List<PackageDef> packages = [];
  final Map<String, Uint8List> media = {}; // caminho no zip -> bytes
  final Set<String> usedMedia = {};
  int get questionCount => packages.fold(0, (a, p) => a + p.questions.length);
}

class ImportResult {
  int questions = 0, skippedQuestions = 0;
  int templatesCreated = 0, templatesReused = 0;
  int sessionsCreated = 0, packagesCreated = 0, tagsCreated = 0, media = 0;
}
