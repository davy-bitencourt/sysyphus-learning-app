import 'dart:convert';
import 'field_model.dart';

/// Uma questão "crua", como ela existe no banco: enunciado fixo +
/// um mapa de valores (um por campo do template, indexado por field.id).
class Question {
  final int? id;
  final int? templateId;
  final int? tagId;
  final int? packageId;
  final String statement;
  final String extraComments;
  final String description;
  final Map<String, dynamic> values;

  /* dados de repetição espaçada (tabela `state`) */
  final String? state;
  final int? intervalDays;
  final double? easeFactor;
  final String? dueDate;

  const Question({
    this.id,
    this.templateId,
    this.tagId,
    this.packageId,
    required this.statement,
    this.values = const {},
    this.extraComments = '',
    this.description = '',
    this.state,
    this.intervalDays,
    this.easeFactor,
    this.dueDate,
  });

  /// Monta a partir de uma linha de `question_state_dao.getByPackage`.
  factory Question.fromDb(Map<String, dynamic> row) {
    final rawQuestions = row['questions'] as String?;
    final values = (rawQuestions != null && rawQuestions.isNotEmpty)
        ? jsonDecode(rawQuestions) as Map<String, dynamic>
        : <String, dynamic>{};

    return Question(
      id: row['id'] as int?,
      templateId: row['template_id'] as int?,
      tagId: row['tag_id'] as int?,
      statement: (values[FieldDefinition.statementId] as String?)?.trim() ?? '',
      values: values,
      extraComments: row['extra'] as String? ?? '',
      description: row['description'] as String? ?? '',
      state: row['state'] as String?,
      intervalDays: row['interval_days'] as int?,
      easeFactor: (row['ease_factor'] as num?)?.toDouble(),
      dueDate: row['due_date'] as String?,
    );
  }

  /// Lê o valor de um campo 'options'/'vof' já decodificado.
  List<OptionValue> optionsFor(String fieldId) {
    final raw = (values[fieldId] as List?) ?? [];
    return raw.map((o) => OptionValue.fromMap(o as Map<String, dynamic>)).toList();
  }

  String? textFor(String fieldId) => values[fieldId] as String?;
}

/// Uma questão já combinada com o [TemplateModel] que ela usa --
/// é o que as telas de estudo/edição efetivamente consomem, já que
/// renderizar uma questão exige saber os campos do template.
class LoadedQuestion {
  final Question question;
  final TemplateModel template;
  const LoadedQuestion({required this.question, required this.template});
}
