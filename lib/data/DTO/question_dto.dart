
/* só para insert/update */
class QuestionDto {

  final int packageId;
  final int? tagId; // opcional: nem toda questão precisa de tag
  final int templateId;
  final String enunciado;
  final String questions;
  final String extra;
  final String description;

  QuestionDto({
    required this.packageId,
    this.tagId,
    required this.templateId,
    required this.enunciado,
    required this.questions,
    required this.extra,
    required this.description,
  });

  Map<String, dynamic> toMap() => {
    'package_id': packageId,
    'tag_id': tagId,
    'template_id': templateId,
    'enunciado': enunciado,
    'questions': questions,
    'extra': extra,
    'description': description,
  };
}
