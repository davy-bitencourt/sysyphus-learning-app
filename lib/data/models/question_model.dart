import 'dart:convert';

enum QuestionType { open, multiple, vof }

QuestionType questionTypeFromString(String value) {
  switch (value) {
    case 'multiple':
      return QuestionType.multiple;
    case 'vof':
      return QuestionType.vof;
    case 'open':
    default:
      return QuestionType.open;
  }
}

String questionTypeToString(QuestionType type) {
  switch (type) {
    case QuestionType.multiple:
      return 'multiple';
    case QuestionType.vof:
      return 'vof';
    case QuestionType.open:
      return 'open';
  }
}

/// Representa um Template (tabela `templates`): define o FORMATO
/// reutilizável de uma questão -- o tipo de interação (aberta / múltipla
/// escolha / verdadeiro-falso) e, quando aplicável, quantas opções ela
/// deve ter. O conteúdo real (textos, respostas certas) fica na questão.
class TemplateModel {
  final int? id;
  final QuestionType type;
  final int optionCount;

  const TemplateModel({
    this.id,
    required this.type,
    this.optionCount = 4,
  });

  factory TemplateModel.fromJson(int id, String rawJson) {
    final map = jsonDecode(rawJson) as Map<String, dynamic>;
    return TemplateModel(
      id: id,
      type: questionTypeFromString(map['type'] as String? ?? 'open'),
      optionCount: map['optionCount'] as int? ?? 4,
    );
  }

  String toJsonString() => jsonEncode({
    'type': questionTypeToString(type),
    'optionCount': optionCount,
  });

  String get label {
    switch (type) {
      case QuestionType.open:
        return 'Questão aberta';
      case QuestionType.multiple:
        return 'Múltipla escolha ($optionCount opções)';
      case QuestionType.vof:
        return 'Verdadeiro ou Falso ($optionCount afirmações)';
    }
  }
}

class QuestionOption {
  final String text;
  final bool correct;
  const QuestionOption({required this.text, this.correct = false});

  factory QuestionOption.fromMap(Map<String, dynamic> map) => QuestionOption(
    text: map['text'] as String? ?? '',
    correct: map['correct'] as bool? ?? false,
  );

  Map<String, dynamic> toMap() => {'text': text, 'correct': correct};
}

/// Questão pronta para exibição/edição, já combinando a linha da tabela
/// `question` com o [TemplateModel] referenciado por `template_id`.
class Question {
  final int? id;
  final int? templateId;
  final int? tagId;
  final int? packageId;
  final String statement;
  final QuestionType type;
  final List<QuestionOption> options;
  final String? suggestion;
  final String extraComments;
  final String description;

  const Question({
    this.id,
    this.templateId,
    this.tagId,
    this.packageId,
    required this.statement,
    required this.type,
    this.options = const [],
    this.suggestion,
    this.extraComments = '',
    this.description = '',
  });

  /// Monta a partir de uma linha de `question_state_dao.getByPackage`
  /// + do [TemplateModel] já resolvido (via TemplateSchema.isOnCache).
  factory Question.fromDb(Map<String, dynamic> row, TemplateModel template) {
    final rawQuestions = row['questions'] as String?;
    final content = (rawQuestions != null && rawQuestions.isNotEmpty)
        ? jsonDecode(rawQuestions) as Map<String, dynamic>
        : <String, dynamic>{};

    List<QuestionOption> options = const [];
    String? suggestion;

    if (template.type == QuestionType.open) {
      suggestion = content['suggestion'] as String?;
    } else {
      final rawOptions = (content['options'] as List?) ?? [];
      options = rawOptions
          .map((o) => QuestionOption.fromMap(o as Map<String, dynamic>))
          .toList();
    }

    return Question(
      id: row['id'] as int?,
      templateId: row['template_id'] as int?,
      tagId: row['tag_id'] as int?,
      statement: row['enunciado'] as String? ?? '',
      type: template.type,
      options: options,
      suggestion: suggestion,
      extraComments: row['extra'] as String? ?? '',
      description: row['description'] as String? ?? '',
    );
  }

  /// Serializa o conteúdo respondível -- o que vai na coluna `questions`.
  String toQuestionsJson() {
    if (type == QuestionType.open) {
      return jsonEncode({'suggestion': suggestion ?? ''});
    }
    return jsonEncode({'options': options.map((o) => o.toMap()).toList()});
  }
}
