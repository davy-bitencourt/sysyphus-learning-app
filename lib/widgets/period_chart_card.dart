import 'package:flutter/material.dart';

import '../data/stats/review_stats.dart';
import '../l10n/strings.dart';
import '../styles/app_theme.dart';
import 'stats_widgets.dart';

enum ChartRange { week, days30, months12 }

class PeriodChartCard extends StatefulWidget {
  const PeriodChartCard({super.key, required this.stats});

  final ReviewStats stats;

  @override
  State<PeriodChartCard> createState() => _PeriodChartCardState();
}

class _PeriodChartCardState extends State<PeriodChartCard> {
  ChartRange _range = ChartRange.week; // semana pré-escolhida

  String _rangeName(ChartRange r) => switch (r) {
        ChartRange.week => context.tr('stats.last7'),
        ChartRange.days30 => context.tr('stats.last30'),
        ChartRange.months12 => context.tr('stats.last12Months'),
      };

@override
Widget build(BuildContext context) {
  return Stack(
    children: [
      StatCard(
        title: _rangeName(_range),
        child: _chart(),
      ),
      Positioned(
        top: 6,
        right: 6,
        child: PopupMenuButton<ChartRange>(
          tooltip: context.tr('stats.changePeriod'),
          color: context.colors.bgSecond,
          onSelected: (r) => setState(() => _range = r),
          icon: Icon(Icons.keyboard_arrow_down, color: context.colors.textMain),
          itemBuilder: (_) => [
            for (final r in ChartRange.values)
              PopupMenuItem(
                value: r,
                child: Text(_rangeName(r), style: TextStyle(color: context.colors.textMain)),
              ),
          ],
        ),
      ),
    ],
  );
}

  Widget _chart() {
    final s = widget.stats;
    switch (_range) {
      case ChartRange.week:
        final week = s.lastDays(7);
        final weekDays = [for (var i = 6; i >= 0; i--) addDays(s.today, -i)];
        return BarChart(
          values: week,
          labels: [for (final d in weekDays) kWeekdayShort[d.weekday - 1]],
          tooltips: [
            for (var i = 0; i < 7; i++) '${formatDayShort(weekDays[i])}: ${formatCount(week[i])}',
          ],
          highlight: 6,
          height: 90,
        );
      case ChartRange.days30:
        final days = [for (var i = 29; i >= 0; i--) addDays(s.today, -i)];
        final values = s.lastDays(30);
        return BarChart(
          values: values,
          tooltips: [
            for (var i = 0; i < 30; i++) '${formatDayShort(days[i])}: ${formatCount(values[i])}',
          ],
          highlight: 29,
          footerStart: formatDayShort(days.first),
          footerEnd: context.tr('stats.today'),
        );
      case ChartRange.months12:
        final months = s.lastMonths(12);
        return BarChart(
          values: [for (final m in months) m.count],
          labels: [for (final m in months) kMonthNames[m.month.month - 1]],
          tooltips: [for (final m in months) '${formatMonth(m.month)}: ${formatCount(m.count)}'],
          highlight: 11,
        );
    }
  }
}