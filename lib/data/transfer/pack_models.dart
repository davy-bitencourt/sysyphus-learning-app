// Modelos e utilidades do formato de importação/exportação (.zip).
// Dart puro (sem Flutter), para poder ser testado isoladamente.

const Set<String> kPackImageExts = {'.png', '.jpg', '.jpeg', '.webp', '.gif'};
const Set<String> kPackAudioExts = {'.mp3', '.m4a', '.wav', '.ogg', '.aac'};

/// Extensão em minúsculas, com o ponto (ex.: '.png'), ou '' se não houver.
String packExtOf(String path) {
  final i = path.lastIndexOf('.');
  return i >= 0 ? path.substring(i).toLowerCase() : '';
}

// Grupos explícitos (letra base -> variações acentuadas): não depende de
// duas listas com o mesmo comprimento.
const Map<String, String> _accentGroups = {
  'a': 'àáâãäåā',
  'c': 'çćč',
  'e': 'èéêëēėę',
  'i': 'ìíîïīį',
  'l': 'ł',
  'n': 'ñń',
  'o': 'òóôõöøō',
  'u': 'ùúûüū',
  'y': 'ýÿ',
  'z': 'žźż',
};

final Map<String, String> _accentMap = _buildAccentMap();

Map<String, String> _buildAccentMap() {
  final map = <String, String>{};
  _accentGroups.forEach((base, variants) {
    for (final rune in variants.runes) {
      map[String.fromCharCode(rune)] = base;
    }
  });
  return map;
}

/// Minúsculas, sem acentos e com espaços colapsados. Usado para comparar
/// nomes e rótulos: "Áudio" == "audio", "Múltipla  escolha" == "multipla escolha".
String normalizeText(String input) {
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_accentMap[ch] ?? ch);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

// ---------------------------------------------------------------------------
// Escape de linhas dentro de campos de texto.
// Uma linha de texto que seria lida como separador ('---'), título ('##') ou
// cerca de código (```) ganha uma barra invertida na frente ao exportar; ao
// importar a barra sai. As duas pontas usam o MESMO critério, então o ciclo
// exportar -> importar devolve o texto original.
// ---------------------------------------------------------------------------

bool packLineNeedsEscape(String line) {
  return line.trim() == '---' ||
      line.startsWith('##') ||
      line.trimLeft().startsWith('```') ||
      line.startsWith(r'\');
}

String packEscapeLine(String line) => packLineNeedsEscape(line) ? '\\$line' : line;

String packUnescapeLine(String line) {
  if (line.startsWith(r'\') && packLineNeedsEscape(line.substring(1))) {
    return line.substring(1);
  }
  return line;
}

// ---------------------------------------------------------------------------
// Problemas encontrados ao ler um pacote
// ---------------------------------------------------------------------------

enum PackIssueLevel { error, warning }

class PackIssue {
  final PackIssueLevel level;
  final String where; // arquivo ou arquivo:linha
  final String message;
  const PackIssue(this.level, this.where, this.message);

  bool get isError => level == PackIssueLevel.error;

  @override
  String toString() => '$where: $message';
}

// ---------------------------------------------------------------------------
// Conteúdo do pacote
// ---------------------------------------------------------------------------

class PackField {
  final String label;
  final String type; // text | image | audio | options | vof
  final String section; // question | answer
  final int optionCount;
  final double? maxWidth;
  final double? maxHeight;

  const PackField({
    required this.label,
    required this.type,
    this.section = 'question',
    this.optionCount = 4,
    this.maxWidth,
    this.maxHeight,
  });

  bool get isGradable => type == 'options' || type == 'vof';
  bool get isMedia => type == 'image' || type == 'audio';
  bool get isStatement => normalizeText(label) == 'enunciado';
}

class PackTemplate {
  final String name;
  final List<PackField> fields;
  const PackTemplate({required this.name, required this.fields});
}

class PackTagFilter {
  final String tag;
  final int quantity;
  const PackTagFilter(this.tag, this.quantity);
}

class PackSession {
  final String title;
  final int? timeLimitSeconds; // null = sem limite
  final int totalQuestions;
  final List<PackTagFilter> tagFilters;
  const PackSession({
    required this.title,
    required this.timeLimitSeconds,
    required this.totalQuestions,
    required this.tagFilters,
  });
}

class PackOption {
  final String text;
  final bool correct;
  const PackOption(this.text, this.correct);
}

class PackQuestion {
  final String packageTitle;
  final String templateName;
  final String? tag; // uma só (o banco guarda uma tag por questão)
  final String statement;

  /// Rótulo normalizado do campo -> String (texto ou caminho de mídia dentro
  /// do zip) ou List<PackOption> (alternativas).
  final Map<String, Object> values;

  final String sourceFile;
  final int line;

  const PackQuestion({
    required this.packageTitle,
    required this.templateName,
    required this.tag,
    required this.statement,
    required this.values,
    required this.sourceFile,
    required this.line,
  });
}

class PackPackage {
  final String title;
  final String? sessionTitle;
  final List<PackQuestion> questions;
  const PackPackage({required this.title, required this.sessionTitle, required this.questions});
}

class PackData {
  final List<PackTemplate> templates;
  final List<PackSession> sessions;
  final List<PackPackage> packages;
  const PackData({required this.templates, required this.sessions, required this.packages});
}

class PackParseResult {
  final PackData data;
  final List<PackIssue> issues;

  /// Caminhos (dentro do zip) das mídias que alguma questão usa.
  final Set<String> mediaUsed;

  const PackParseResult({required this.data, required this.issues, required this.mediaUsed});

  List<PackIssue> get errors => issues.where((i) => i.isError).toList();
  List<PackIssue> get warnings => issues.where((i) => !i.isError).toList();
  bool get hasErrors => issues.any((i) => i.isError);

  int get questionCount => data.packages.fold(0, (sum, p) => sum + p.questions.length);
}
