
class SessionDto {

  final int id;
  final String title;
  final String? time_limit;
  final int? total_q;

  SessionDto({
    required this.id,
    required this.title,
    this.time_limit,
    this.total_q,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'time_limit': time_limit,
    'total_q': total_q,
  };
}