class Session {
  final int? id;
  final String? title;
  final String? timeLimit;
  final int? totalQ;

  Session({
    this.id,
    this.title,
    this.timeLimit,
    this.totalQ,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'time_limit': timeLimit,
    'total_q': totalQ,
  };

  factory Session.fromMap(Map<String, dynamic> map) => Session(
    id: map['id'],
    title: map['title'],
    timeLimit: map['time_limit'],
    totalQ: map['total_q'],
  );
}