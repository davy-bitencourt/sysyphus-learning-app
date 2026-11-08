
class SessionDto {

  final int? id; // null ao criar; obrigatório apenas ao atualizar
  final String title;
  final String? time_limit;
  final int? total_q;
  /// Filtro por tag, em JSON: [{"tag_id": 1, "quantity": 10}]. null = sem filtro.
  final String? tagFilters;
  /// true = a sessão oferta só as questões pendentes pelo algoritmo (SM-2).
  final bool spacedRepetition;

  SessionDto({
    this.id,
    required this.title,
    this.time_limit,
    this.total_q,
    this.tagFilters,
    this.spacedRepetition = false,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'time_limit': time_limit,
    'total_q': total_q,
    'tag_filters': tagFilters,
    'spaced_repetition': spacedRepetition ? 1 : 0,
  };
}
