class QuestionDto {
  final int packageId;
  final int? tagId; // opcional: nem toda questão precisa de tag
  final int templateId;
  final String questions;

  QuestionDto({
    required this.packageId,
    this.tagId,
    required this.templateId,
    required this.questions,
  });

  Map<String, dynamic> toMap() => {
    'package_id': packageId,
    'tag_id': tagId,
    'template_id': templateId,
    'questions': questions,
  };
}