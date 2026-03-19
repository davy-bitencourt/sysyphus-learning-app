class Template {
  final int? id;
  final String? template; // JSON

  Template({this.id, this.template});

  Map<String, dynamic> toMap() => {
    'id': id,
    'template': template,
  };

  factory Template.fromMap(Map<String, dynamic> map) => Template(
    id: map['id'],
    template: map['template'],
  );
}