import 'package:flutter/material.dart';

import '../styles/text_styles.dart';

class HeatmapCard extends StatelessWidget {
  final Map<DateTime, int> activityMap;  // recebe os dados de fora

  const HeatmapCard({super.key, required this.activityMap});

  Color _heatColor(int value) {
    switch (value) {
      case 1:  return const Color(0xFFFFE082); // amarelo claro
      case 2:  return const Color(0xFFFFB300); // âmbar
      case 3:  return const Color(0xFFFF8F00); // laranja âmbar
      case 4:  return const Color(0xFFE65100); // laranja escuro
      default: return const Color(0xFFEBEDF0); // cinza (sem atividade)
    }
  }   

  Widget build(BuildContext context) {
    const double cellSize  = 11;
    const double cellGap   = 2;
    const double cellStep  = cellSize + cellGap;
    const double dayLabelW = 26;
    const double labelGap  = 4;

    final today       = DateTime.now();
    final todayNorm   = DateTime(today.year, today.month, today.day);
    final monthNames  = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

    return Center(
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800),
      child: Container(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(builder: (context, constraints) {
        final double availW = constraints.maxWidth - dayLabelW - labelGap;
        final DateTime yearStart = DateTime(2026, 1, 1);
        final DateTime firstMonday = yearStart.subtract(Duration(days: yearStart.weekday % 7));
        final DateTime yearEnd = DateTime(2026, 12, 31);
        final DateTime lastMonday = yearEnd.subtract(Duration(days: yearEnd.weekday - 1));

        final int totalCols = lastMonday.difference(firstMonday).inDays ~/ 7 + 1;
        final int visibleCols = (availW / cellStep).floor().clamp(1, totalCols);
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
                    const Text('365 questions this day', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const Text('12 day streak', style: TextStyle(fontSize: 11, color: Color(0xFFFF8F00), fontWeight: FontWeight.w600)),
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
                            final monday = firstMonday.add(Duration(days: ci * 7));
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
                          final monday = firstMonday.add(Duration(days: ci * 7));
                          return Padding(
                            padding: const EdgeInsets.only(right: cellGap),
                            child: Column(
                              children: List.generate(7, (d) {
                                final date    = monday.add(Duration(days: d));
                                final dateKey = DateTime(date.year, date.month, date.day);
                                final isToday  = dateKey == todayNorm;
                                final isFuture = date.isAfter(todayNorm) && date.year == 2026;
                                final isOutOfYear = date.isBefore(DateTime(2026, 1, 1));
                                final value = isFuture ? 0 : (activityMap[dateKey] ?? 0);
                                return Container(
                                  width: cellSize, height: cellSize,
                                  margin: const EdgeInsets.only(bottom: cellGap),
                                  decoration: BoxDecoration(
                                    color: isOutOfYear ? Colors.transparent : isFuture ? const Color(0xFFEBEDF0) : _heatColor(value),                                    
                                    borderRadius: BorderRadius.circular(2),
                                    border: isToday ? Border.all(color: const Color(0xFF1565C0), width: 1.5) : null,
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
                    decoration: BoxDecoration(color: _heatColor(v), borderRadius: BorderRadius.circular(2)),
                  )),
                  Text('More', style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                ]),
                Row(children: [
                  Text('60', style: const TextStyle(fontSize: 10, color: Color(0xFF1565C0), fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Text('10', style: const TextStyle(fontSize: 10, color: Color(0xFFC62828), fontWeight: FontWeight.w600)),
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