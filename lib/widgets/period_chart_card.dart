import 'package:flutter/material.dart';

import '../data/stats/review_stats.dart';
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

  static const _names = {
    ChartRange.week: 'Last 7 days',
    ChartRange.days30: 'Last 30 days',
    ChartRange.months12: 'Last 12 months',
  };

  Future<void> _pickRange() async {
    final picked = await showModalBottomSheet<ChartRange>(
      context: context,
      backgroundColor: context.colors.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in ChartRange.values)
              ListTile(
                title: Text(_names[r]!, style: TextStyle(color: context.colors.text)),
                trailing: r == _range ? Icon(Icons.check, color: context.colors.accent) : null,
                onTap: () => Navigator.pop(sheetContext, r),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _range = picked);
  }

@override
Widget build(BuildContext context) {
  return Stack(
    children: [
      StatCard(
        title: _names[_range]!,
        icon: _range == ChartRange.months12 ? Icons.calendar_month_outlined : Icons.show_chart,
        child: _chart(),
      ),
      Positioned(
        top: 6,
        right: 6,
        child: IconButton(
          tooltip: 'Change period',
          onPressed: _pickRange,
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.keyboard_arrow_down, color: context.colors.text),
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
          footerEnd: 'Today',
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
