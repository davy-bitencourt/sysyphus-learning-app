import 'package:flutter/material.dart';

import '../data/stats/review_stats.dart';
import '../l10n/strings.dart';
import '../styles/app_theme.dart';
import '../widgets/period_chart_card.dart';
import '../widgets/stats_widgets.dart';
import '../widgets/responsive_columns.dart';
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
            : _message(context, Icons.error_outline, context.tr('stats.loadFailed'), _error!),
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
            child: _message(context, Icons.bar_chart_outlined, context.tr('stats.noData'),
              context.tr('stats.noDataHint')),
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

  return ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    children: [
      ResponsiveColumns(
        maxColumns: 2,
        children: [
          StatGrid(children: [
            StatTile(label: context.tr('stats.today'), value: formatCount(stats.reviewsToday), caption: context.tr('stats.reviews')),
            StatTile(
              label: context.tr('stats.currentStreak'),
              value: formatDays(streak.length),
              caption: context.tr('stats.longestCaption', {'days': formatDays(longest.length)}),
            ),
            StatTile(label: context.tr('stats.last7'), value: formatCount(stats.last7), caption: context.tr('stats.reviews')),
            StatTile(
              label: context.tr('stats.total'),
              value: formatCount(stats.total),
              caption: context.tr('stats.inStudied', {'days': formatDays(stats.daysStudied)}),
            ),
          ]),
          PeriodChartCard(stats: stats),
        ],
      ),
    ],
  );
}
}
