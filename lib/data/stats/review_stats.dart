import 'dart:math' as math;

import '../DAO/revlog_dao.dart';

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Dias de calendário entre [a] e [b] (b - a), sem erro de horário de verão.
int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Segunda-feira da semana de [d].
DateTime weekStart(DateTime d) => addDays(dayOf(d), -(d.weekday - 1));

class Streak {
  final int length;
  final DateTime? start;
  final DateTime? end;
  const Streak(this.length, {this.start, this.end});
}

/// Maior valor de um período (dia, semana ou mês que começa em [start]).
class Peak {
  final DateTime start;
  final int count;
  const Peak(this.start, this.count);
}

class MonthTotal {
  final DateTime month; // dia 1 do mês
  final int count;
  const MonthTotal(this.month, this.count);
}

/// Estatísticas de estudo calculadas a partir de "revisões por dia" (a mesma
/// fonte do heatmap). Não depende de tela: a Home usa o resumo e a tela de
/// estatísticas detalhadas usa o restante.
class ReviewStats {
  /// [daily]: um item por dia de calendário (já sem horário) com ao menos uma revisão.
  ReviewStats(Map<DateTime, int> daily, {DateTime? now})
      : daily = {
          for (final e in daily.entries)
            if (e.value > 0) dayOf(e.key): e.value,
        },
        today = dayOf(now ?? DateTime.now());

  final Map<DateTime, int> daily;
  final DateTime today;

  static Future<ReviewStats> load() async {
    final raw = await RevlogDao().getCountPerDay();
    final daily = <DateTime, int>{};
    raw.forEach((dateString, count) {
      final parsed = DateTime.tryParse(dateString);
      if (parsed == null) return;
      final d = dayOf(parsed);
      daily[d] = (daily[d] ?? 0) + (count as num).toInt();
    });
    return ReviewStats(daily);
  }

  // ------------------------------------------------------------ básicos

  late final List<DateTime> _sortedDays = daily.keys.toList()..sort();
  late final int total = daily.values.fold(0, (a, b) => a + b);
  int get daysStudied => daily.length;
  bool get isEmpty => total == 0;
  DateTime? get firstDay => _sortedDays.isEmpty ? null : _sortedDays.first;

  int countOn(DateTime d) => daily[dayOf(d)] ?? 0;

  /// Soma de [from] a [to], inclusive.
  int sumRange(DateTime from, DateTime to) {
    var sum = 0;
    for (var d = dayOf(from); !d.isAfter(to); d = addDays(d, 1)) {
      sum += countOn(d);
    }
    return sum;
  }

  // ------------------------------------------------------------ períodos

  int get reviewsToday => countOn(today);
  int get reviewsYesterday => countOn(addDays(today, -1));
  int get last7 => sumRange(addDays(today, -6), today);
  int get previous7 => sumRange(addDays(today, -13), addDays(today, -7));
  int get last30 => sumRange(addDays(today, -29), today);
  int get previous30 => sumRange(addDays(today, -59), addDays(today, -30));
  int get last365 => sumRange(addDays(today, -364), today);
  int get previous365 => sumRange(addDays(today, -729), addDays(today, -365));

  /// Quantos dos últimos [n] dias tiveram ao menos uma revisão.
  int daysStudiedIn(int n) {
    var count = 0;
    for (var i = 0; i < n; i++) {
      if (countOn(addDays(today, -i)) > 0) count++;
    }
    return count;
  }

  // ------------------------------------------------------------- médias

  double get avgPerStudiedDay => daysStudied == 0 ? 0 : total / daysStudied;

  /// Média por dia de calendário desde a primeira revisão (conta os dias sem estudo).
  double get avgPerDay {
    final first = firstDay;
    if (first == null) return 0;
    return total / math.max(1, daysBetween(first, today) + 1);
  }

  // ------------------------------------------------------------ sequências

  /// Sequência atual. Se hoje ainda não teve revisão, a de ontem continua valendo.
  Streak get currentStreak {
    var d = countOn(today) > 0 ? today : addDays(today, -1);
    final end = d;
    var length = 0;
    while (countOn(d) > 0) {
      length++;
      d = addDays(d, -1);
    }
    return length == 0 ? const Streak(0) : Streak(length, start: addDays(d, 1), end: end);
  }

  late final Streak longestStreak = () {
    var best = const Streak(0);
    DateTime? runStart;
    DateTime? previous;
    for (final d in _sortedDays) {
      if (previous == null || daysBetween(previous, d) != 1) runStart = d;
      previous = d;
      final length = daysBetween(runStart!, d) + 1;
      if (length > best.length) best = Streak(length, start: runStart, end: d);
    }
    return best;
  }();

  // ------------------------------------------------------------- recordes

  Peak? _bestBy(DateTime Function(DateTime) bucket) {
    final sums = <DateTime, int>{};
    daily.forEach((d, c) {
      final key = bucket(d);
      sums[key] = (sums[key] ?? 0) + c;
    });
    Peak? best;
    for (final e in sums.entries) {
      if (best == null || e.value > best.count) best = Peak(e.key, e.value);
    }
    return best;
  }

  Peak? get bestDay => _bestBy((d) => d);
  Peak? get bestWeek => _bestBy(weekStart);
  Peak? get bestMonth => _bestBy((d) => DateTime(d.year, d.month));

  // -------------------------------------------------------------- gráficos

  /// Revisões por dia dos últimos [n] dias (o último é hoje).
  List<int> lastDays(int n) => [for (var i = n - 1; i >= 0; i--) countOn(addDays(today, -i))];

  /// Total por mês dos últimos [n] meses (o último é o mês atual).
  List<MonthTotal> lastMonths(int n) {
    final sums = <int, int>{};
    daily.forEach((d, c) {
      final key = d.year * 12 + d.month - 1;
      sums[key] = (sums[key] ?? 0) + c;
    });
    final result = <MonthTotal>[];
    for (var i = n - 1; i >= 0; i--) {
      final m = DateTime(today.year, today.month - i);
      result.add(MonthTotal(m, sums[m.year * 12 + m.month - 1] ?? 0));
    }
    return result;
  }

  /// Média de revisões por dia da semana (0 = segunda ... 6 = domingo), contando
  /// também os dias sem estudo desde a primeira revisão.
  late final List<double> weekdayAverages = () {
    final first = firstDay;
    final totals = List<int>.filled(7, 0);
    daily.forEach((d, c) => totals[d.weekday - 1] += c);
    final occurrences = List<int>.filled(7, 0);
    if (first != null) {
      for (var d = first; !d.isAfter(today); d = addDays(d, 1)) {
        occurrences[d.weekday - 1]++;
      }
    }
    return [for (var i = 0; i < 7; i++) occurrences[i] == 0 ? 0.0 : totals[i] / occurrences[i]];
  }();

  /// Índice (0 = segunda) do dia da semana mais ativo, ou null sem dados.
  int? get busiestWeekday {
    var best = -1;
    for (var i = 0; i < 7; i++) {
      if (weekdayAverages[i] > 0 && (best == -1 || weekdayAverages[i] > weekdayAverages[best])) {
        best = i;
      }
    }
    return best == -1 ? null : best;
  }
}
