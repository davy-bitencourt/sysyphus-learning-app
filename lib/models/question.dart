class Question {
  final int? id;
  final int? packageId;
  final int? tagId;
  final int? templateId;
  final String? enunciado;
  final String? questions; // JSON
  final String? extra;     // JSON
  final String? description;

  Question({
    this.id,
    this.packageId,
    this.tagId,
    this.templateId,
    this.enunciado,
    this.questions,
    this.extra,
    this.description,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'package_id': packageId,
    'tag_id': tagId,
    'template_id': templateId,
    'enunciado': enunciado,
    'questions': questions,
    'extra': extra,
    'description': description,
  };

  factory Question.fromMap(Map<String, dynamic> map) => Question(
    id: map['id'],
    packageId: map['package_id'],
    tagId: map['tag_id'],
    templateId: map['template_id'],
    enunciado: map['enunciado'],
    questions: map['questions'],
    extra: map['extra'],
    description: map['description'],
  );
}