import 'dart:convert';

/// Tipos de campo suportados por um template.
///
/// De propósito isto é uma lista de Strings, não um enum fechado do Dart:
/// pra adicionar um tipo novo no futuro basta (1) adicionar a constante e o
/// label aqui e (2) criar o widget de edição/exibição correspondente nas
/// telas -- sem precisar migrar o formato já salvo no banco.
class FieldType {
  static const text = 'text';
  static const image = 'image';
  static const audio = 'audio';
  static const options = 'options'; // múltipla escolha
  static const vof = 'vof';         // verdadeiro ou falso

  /// Tipos disponíveis ao CRIAR um campo. `vof` foi retirado da lista de
  /// propósito (não dá mais pra criar), mas a constante e o suporte de
  /// leitura continuam, para templates/questões antigos não quebrarem.
  static const all = [text, image, audio, options];

  static String label(String type) {
    switch (type) {
      case text: return 'Texto';
      case image: return 'Imagem';
      case audio: return 'Áudio';
      case options: return 'Múltipla escolha';
      case vof: return 'Verdadeiro ou Falso';
      default: return type;
    }
  }

  static bool needsOptionCount(String type) => type == options || type == vof;

  /// Campos de resposta (options/vof) só fazem sentido antes de responder
  /// -- é neles que o usuário interage pra dar a resposta.
  static bool isGradable(String type) => type == options || type == vof;
}

/// Em qual momento da tela de estudo o campo aparece.
class FieldSection {
  static const question = 'question'; // sempre visível
  static const answer = 'answer';     // só depois de "Mostrar Resposta"

  static const all = [question, answer];

  static String label(String section) =>
      section == answer ? 'Depois de responder' : 'Antes de responder';
}

/// Um campo dentro de um template: define o "molde" que toda questão
/// criada com esse template vai ter. O valor de cada campo fica guardado,
/// por `id`, dentro da coluna `questions` (JSON) da tabela `question`.
class FieldDefinition {
  final String id;
  final String type;    // um dos FieldType.*
  final String label;
  final String section; // um dos FieldSection.*
  final int optionCount; // só relevante para 'options'/'vof'

  /// Id fixo do campo "Enunciado", presente em TODO template.
  static const statementId = 'statement';
  static const statement = FieldDefinition(
    id: statementId,
    type: FieldType.text,
    label: 'Enunciado',
  );

  bool get isStatement => id == statementId;

  const FieldDefinition({
    required this.id,
    required this.type,
    required this.label,
    this.section = FieldSection.question,
    this.optionCount = 4,
  });

  factory FieldDefinition.fromMap(Map<String, dynamic> map) => FieldDefinition(
    id: map['id'] as String,
    type: map['type'] as String,
    label: map['label'] as String? ?? '',
    section: map['section'] as String? ?? FieldSection.question,
    optionCount: map['optionCount'] as int? ?? 4,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type,
    'label': label,
    'section': section,
    'optionCount': optionCount,
  };
}

/// Representa um Template (tabela `templates`): uma lista ordenada de
/// campos que define o formato de uma questão. Guardado como JSON puro
/// na coluna `template`.
class TemplateModel {
  final int? id;
  final String name;
  final List<FieldDefinition> fields;

  const TemplateModel({
    this.id,
    required this.name,
    required this.fields,
  });

  /// Campos que aparecem sempre (antes de responder).
  List<FieldDefinition> get questionFields =>
      fields.where((f) => f.section == FieldSection.question).toList();

  /// Campos que só aparecem depois de responder (ex: explicação, gabarito,
  /// uma imagem/áudio complementar).
  List<FieldDefinition> get answerFields =>
      fields.where((f) => f.section == FieldSection.answer).toList();

  /// Garante que o enunciado exista, sempre como primeiro campo.
  /// Templates antigos (sem enunciado) são migrados na leitura.
  static List<FieldDefinition> withStatement(List<FieldDefinition> fields) =>
      [FieldDefinition.statement, ...fields.where((f) => !f.isStatement)];

  factory TemplateModel.fromJson(int id, String rawJson) =>
      TemplateModel.fromMap(id, jsonDecode(rawJson) as Map<String, dynamic>);

  /// Usado quando o JSON já veio decodificado (ex: cache do TemplateSchema).
  factory TemplateModel.fromMap(int id, Map<String, dynamic> map) {
    final rawFields = (map['fields'] as List?) ?? [];
    return TemplateModel(
      id: id,
      name: map['name'] as String? ?? 'Template',
      fields: withStatement(
        rawFields
            .map((f) => FieldDefinition.fromMap(f as Map<String, dynamic>))
            .toList(),
      ),
    );
  }

  String toJsonString() => jsonEncode({
    'name': name,
    'fields': withStatement(fields).map((f) => f.toMap()).toList(),
  });
}

class OptionValue {
  final String text;
  final bool correct;
  const OptionValue({required this.text, this.correct = false});

  factory OptionValue.fromMap(Map<String, dynamic> map) => OptionValue(
    text: map['text'] as String? ?? '',
    correct: map['correct'] as bool? ?? false,
  );

  Map<String, dynamic> toMap() => {'text': text, 'correct': correct};
}
