import 'package:flutter/material.dart';

import '../styles/app_theme.dart';
import '../styles/text_styles.dart';

class HeatmapCard extends StatelessWidget {
  final Map<DateTime, int> activityMap;  // recebe os dados de fora
  final int newCount; // questões novas (nunca vistas)
  final int dueCount; // questões para revisar (vencidas ou esquecidas)

  const HeatmapCard({
    super.key,
    required this.activityMap,
    this.newCount = 0,
    this.dueCount = 0,
  });

  /// Converte a QUANTIDADE de revisões do dia em um nível de 0 a 4.
  /// (Antes o número de revisões ia direto pro switch: a partir de 5
  /// revisões no dia caía no `default` e a célula ficava cinza.)
  int _levelFor(int count) {
    if (count <= 0) return 0;
    if (count <= 4) return 1;
    if (count <= 9) return 2;
    if (count <= 19) return 3;
    return 4;
  }

  Color _heatColor(int count, AppColors c) => _colorForLevel(_levelFor(count), c);

  /// Cor do nível 0..4 na paleta escolhida nas configurações.
  Color _colorForLevel(int level, AppColors c) => c.heat[level.clamp(0, 4)];

  /// Dias seguidos com pelo menos uma revisão, terminando hoje. Se hoje ainda
  /// não teve revisão, a sequência de ontem continua valendo (ela só quebra
  /// quando um dia inteiro passa sem estudar).
  int _streak(Map<DateTime, int> map, DateTime todayNorm) {
    bool studied(DateTime d) => (map[d] ?? 0) > 0;

    var day = todayNorm;
    if (!studied(day)) day = DateTime(day.year, day.month, day.day - 1);

    int count = 0;
    while (studied(day)) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    const double cellSize  = 11;
    const double cellGap   = 2;
    const double cellStep  = cellSize + cellGap;
    const double dayLabelW = 26;
    const double labelGap  = 4;

    final today       = DateTime.now();
    final todayNorm   = DateTime(today.year, today.month, today.day);
    final c           = context.colors;
    final todayCount  = activityMap[todayNorm] ?? 0;
    final streak      = _streak(activityMap, todayNorm);
    final monthNames  = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

    return Center(
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800),
      child: Container(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(builder: (context, constraints) {
        final double availW = constraints.maxWidth - dayLabelW - labelGap;
        final DateTime yearStart = DateTime(today.year, 1, 1);
        final DateTime firstMonday = yearStart.subtract(Duration(days: yearStart.weekday % 7));
        final DateTime yearEnd = DateTime(today.year, 12, 31);
        final DateTime lastMonday = yearEnd.subtract(Duration(days: yearEnd.weekday - 1));

        final int totalCols = lastMonday.difference(firstMonday).inDays ~/ 7 + 1;
        final int visibleCols = (availW / cellStep).floor().clamp(1, totalCols);

        // Alinha a grade para sempre mostrar a semana atual (em vez de
        // travar sempre no início do ano quando nem todas as colunas
        // cabem na largura disponível).
        final int todayWeekIndex = todayNorm.difference(firstMonday).inDays ~/ 7;
        final int maxStartCol = (totalCols - visibleCols).clamp(0, totalCols - 1);
        final int startCol = (todayWeekIndex - visibleCols + 1).clamp(0, maxStartCol);

        final double gridW = visibleCols * (cellSize + cellGap);        
        
        return SizedBox(
          width: gridW + dayLabelW + labelGap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Study Activity', style: mediumText),
                  const SizedBox(height: 2),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('$todayCount reviewed today', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    Text('$streak day streak', style: TextStyle(fontSize: 11, color: c.accent, fontWeight: FontWeight.w600)),
                  ]),
                ]),
              ),
            ]),
            const SizedBox(height: 5),

            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: dayLabelW,
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const SizedBox(height: 14),
                  ...List.generate(7, (i) {
                    final label = i == 0 ? 'Sun' : i == 2 ? 'Tue' : i == 4 ? 'Thu' : i == 6 ? 'Sat' : '';
                    return SizedBox(
                      height: cellStep,
                      child: Text(label,
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 7, color: Colors.grey[400])),
                    );
                  }),
                ]),
              ),
              SizedBox(width: labelGap),

              ClipRect(
                child: SizedBox(
                  width: gridW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 14,
                        child: Stack(
                          children: List.generate(visibleCols, (ci) {
                            final monday = firstMonday.add(Duration(days: (startCol + ci) * 7));
                            String? label;
                            for (int d = 0; d < 7; d++) {
                              final day = monday.add(Duration(days: d));
                              if (day.day == 1) { label = monthNames[day.month - 1]; break; }
                            }
                            if (label == null) return const SizedBox.shrink();
                            return Positioned(
                              left: ci * cellStep.toDouble(),
                              child: Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                            );
                          }),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(visibleCols, (ci) {
                          final monday = firstMonday.add(Duration(days: (startCol + ci) * 7));
                          return Padding(
                            padding: const EdgeInsets.only(right: cellGap),
                            child: Column(
                              children: List.generate(7, (d) {
                                final date    = monday.add(Duration(days: d));
                                final dateKey = DateTime(date.year, date.month, date.day);
                                final isToday  = dateKey == todayNorm;
                                final isFuture = date.isAfter(todayNorm) && date.year == today.year;
                                final isOutOfYear = date.isBefore(DateTime(today.year, 1, 1));
                                final value = isFuture ? 0 : (activityMap[dateKey] ?? 0);
                                return Container(
                                  width: cellSize, height: cellSize,
                                  margin: const EdgeInsets.only(bottom: cellGap),
                                  decoration: BoxDecoration(
                                    color: isOutOfYear ? Colors.transparent : isFuture ? c.heat[0] : _heatColor(value, c),                                    
                                    borderRadius: BorderRadius.circular(2),
                                    border: isToday ? Border.all(color: c.accent, width: 1.5) : null,
                                  ),
                                );
                              }),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Text('Less', style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                  const SizedBox(width: 4),
                  ...[0, 1, 2, 3, 4].map((v) => Container(
                    width: 9, height: 9,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(color: _colorForLevel(v, c), borderRadius: BorderRadius.circular(2)),
                  )),
                  Text('More', style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                ]),
                Row(children: [
                  Text('+$newCount', style: const TextStyle(fontSize: 10, color: Color(0xFF1565C0), fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Text('$dueCount', style: TextStyle(fontSize: 10, color: c.accent, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                ]),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),);
      }),
    ),), 
    );
  }
}