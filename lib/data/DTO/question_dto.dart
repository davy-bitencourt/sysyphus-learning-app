
/* só para insert */
class QuestionDto {
  final int packageId;
  final int tagId;
  final int templateId;
  final String enunciado;
  final String questions;
  final String extra;
  final String description;

  QuestionDto({
    required this.packageId,
    required this.tagId,
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