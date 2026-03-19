class Package {
  final int? id;
  final int? sessionId;
  final String title;

  Package({
    this.id,
    this.sessionId,
    required this.title,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'session_id': sessionId,
    'title': title,
  };

  factory Package.fromMap(Map<String, dynamic> map) => Package(
    id: map['id'],
    sessionId: map['session_id'],
    title: map['title'],
  );
}