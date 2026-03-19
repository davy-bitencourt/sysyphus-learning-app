class Tag {
  final int? id;
  final String? title;

  Tag({this.id, this.title});

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
  };

  factory Tag.fromMap(Map<String, dynamic> map) => Tag(
    id: map['id'],
    title: map['title'],
  );
}