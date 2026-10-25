import 'package:flutter/material.dart';

import '../data/stats/review_stats.dart';
import '../styles/app_theme.dart';
import '../widgets/stats_widgets.dart';
import 'home.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  ReviewStats? _stats;
  String? _error;

  @override
  void initState() {
    super.initState();
    Home.packagesChanged.addListener(_load); 
    _load();
  }

  @override
  void dispose() {
    Home.packagesChanged.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final stats = await ReviewStats.load();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _error = null;
      });
    } catch (e) {
      debugPrint('Erro ao carregar as estatísticas: $e');
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    if (stats == null) {
      return Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : _message(context, Icons.error_outline, 'Could not load statistics', _error!),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: stats.isEmpty ? _empty(context) : _summary(context, stats),
    );
  }

  Widget _empty(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: _message(context, Icons.bar_chart_outlined, 'No data yet',
              'Start studying to see your statistics here.'),
          ),
        ),
      ),
    );
  }

  Widget _message(BuildContext context, IconData icon, String title, String text) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: context.icon(64), color: c.border),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.text)),
          const SizedBox(height: 4),
          Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _summary(BuildContext context, ReviewStats stats) {
    final streak = stats.currentStreak;
    final longest = stats.longestStreak;
    final week = stats.lastDays(7);
    final weekDays = [for (var i = 6; i >= 0; i--) addDays(stats.today, -i)];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        StatGrid(children: [
          StatTile(label: 'Today', value: formatCount(stats.reviewsToday), caption: 'reviews'),
          StatTile(
            label: 'Current streak',
            value: formatDays(streak.length),
            caption: 'Longest: ${formatDays(longest.length)}',
          ),
          StatTile(label: 'Last 7 days', value: formatCount(stats.last7), caption: 'reviews'),
          StatTile(
            label: 'Total',
            value: formatCount(stats.total),
            caption: 'in ${formatDays(stats.daysStudied)} studied',
          ),
        ]),
        const SizedBox(height: 12),
        StatCard(
          title: 'Last 7 days',
          icon: Icons.show_chart,
          child: BarChart(
            values: week,
            labels: [for (final d in weekDays) kWeekdayShort[d.weekday - 1]],
            tooltips: [
              for (var i = 0; i < 7; i++) '${formatDayShort(weekDays[i])}: ${formatCount(week[i])}',
            ],
            highlight: 6,
            height: 90,
          ),
        ),
      ],
    );
  }
}
