import 'package:flutter/material.dart';

import '../data/DAO/revlog_dao.dart';
import '../data/stats/review_stats.dart';
import '../styles/app_theme.dart';
import '../widgets/stats_widgets.dart';
import 'home.dart';

class DetailedStatisticsScreen extends StatefulWidget {
  const DetailedStatisticsScreen({super.key});

  @override
  State<DetailedStatisticsScreen> createState() => _DetailedStatisticsScreenState();
}

class _DetailedStatisticsScreenState extends State<DetailedStatisticsScreen> {
  static const Color _danger = Color(0xFFC62828);

  ReviewStats? _stats;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Detailed statistics',
          style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: SafeArea(
        top: false, // a AppBar já cuida do topo
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [..._content(context), const SizedBox(height: 4), _buildDataSection(context)],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context) {
    final c = context.colors;
    final stats = _stats;

    if (stats == null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: _error == null
                ? const CircularProgressIndicator()
                : Text('Could not load statistics: $_error',
                    textAlign: TextAlign.center, style: TextStyle(color: c.mutedText)),
          ),
        ),
      ];
    }

    if (stats.isEmpty) {
      return [
        StatCard(
          title: 'No reviews yet',
          icon: Icons.insights_outlined,
          child: Text(
            'Your detailed statistics appear here after you study your first questions.',
            style: TextStyle(fontSize: 13, color: c.mutedText),
          ),
        ),
      ];
    }

    return [
      _overview(stats),
      _recentActivity(context, stats),
      _last30Days(stats),
      _last12Months(stats),
      _streaks(stats),
      _records(stats),
      _weekdays(context, stats),
    ];
  }

  Widget _overview(ReviewStats s) {
    return StatCard(
      title: 'Overview',
      icon: Icons.insights_outlined,
      child: StatGrid(children: [
        StatTile(label: 'Total reviews', value: formatCount(s.total), outlined: true),
        StatTile(
          label: 'Days studied',
          value: formatCount(s.daysStudied),
          caption: s.firstDay == null ? null : 'since ${formatDay(s.firstDay!)}',
          outlined: true,
        ),
        StatTile(
          label: 'Avg per study day',
          value: formatAverage(s.avgPerStudiedDay),
          caption: 'reviews',
          outlined: true,
        ),
        StatTile(
          label: 'Avg per day',
          value: formatAverage(s.avgPerDay),
          caption: 'counting days off',
          outlined: true,
        ),
      ]),
    );
  }

  Widget _recentActivity(BuildContext context, ReviewStats s) {
    final c = context.colors;
    return StatCard(
      title: 'Recent activity',
      icon: Icons.event_note_outlined,
      child: Column(
        children: [
          PeriodRow(label: 'Today', value: s.reviewsToday, previous: s.reviewsYesterday),
          PeriodRow(label: 'Last 7 days', value: s.last7, previous: s.previous7),
          PeriodRow(label: 'Last 30 days', value: s.last30, previous: s.previous30),
          PeriodRow(label: 'Last 365 days', value: s.last365, previous: s.previous365),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Arrows compare with the period right before (yesterday, the 7, 30 or 365 days before).',
              style: TextStyle(fontSize: 11, color: c.mutedText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _last30Days(ReviewStats s) {
    final days = [for (var i = 29; i >= 0; i--) addDays(s.today, -i)];
    final values = s.lastDays(30);
    return StatCard(
      title: 'Last 30 days',
      icon: Icons.show_chart,
      child: BarChart(
        values: values,
        tooltips: [for (var i = 0; i < 30; i++) '${formatDayShort(days[i])}: ${formatCount(values[i])}'],
        highlight: 29,
        footerStart: formatDayShort(days.first),
        footerEnd: 'Today',
      ),
    );
  }

  Widget _last12Months(ReviewStats s) {
    final months = s.lastMonths(12);
    return StatCard(
      title: 'Last 12 months',
      icon: Icons.calendar_month_outlined,
      child: BarChart(
        values: [for (final m in months) m.count],
        labels: [for (final m in months) kMonthNames[m.month.month - 1]],
        tooltips: [for (final m in months) '${formatMonth(m.month)}: ${formatCount(m.count)}'],
        highlight: 11,
      ),
    );
  }

  Widget _streaks(ReviewStats s) {
    final current = s.currentStreak;
    final longest = s.longestStreak;
    String pct(int n, int of) => '$n of $of days (${(n / of * 100).round()}%)';
    return StatCard(
      title: 'Streaks and consistency',
      icon: Icons.local_fire_department_outlined,
      child: Column(
        children: [
          StatRow('Current streak', formatDays(current.length)),
          if (current.start != null)
            StatRow('Current streak since', formatDay(current.start!)),
          StatRow('Longest streak', formatDays(longest.length)),
          if (longest.start != null && longest.end != null)
            StatRow('Longest streak period',
              longest.length == 1
                  ? formatDay(longest.start!)
                  : '${formatDayShort(longest.start!)} – ${formatDay(longest.end!)}'),
          StatRow('Studied in the last 30 days', pct(s.daysStudiedIn(30), 30)),
          StatRow('Studied in the last 90 days', pct(s.daysStudiedIn(90), 90)),
        ],
      ),
    );
  }

  Widget _records(ReviewStats s) {
    final day = s.bestDay;
    final week = s.bestWeek;
    final month = s.bestMonth;
    return StatCard(
      title: 'Records',
      icon: Icons.emoji_events_outlined,
      child: Column(
        children: [
          if (day != null) StatRow('Best day', '${formatCount(day.count)} · ${formatDay(day.start)}'),
          if (week != null)
            StatRow('Best week', '${formatCount(week.count)} · week of ${formatDayShort(week.start)}'),
          if (month != null)
            StatRow('Best month', '${formatCount(month.count)} · ${formatMonth(month.start)}'),
        ],
      ),
    );
  }

  Widget _weekdays(BuildContext context, ReviewStats s) {
    final averages = s.weekdayAverages;
    final busiest = s.busiestWeekday;
    return StatCard(
      title: 'Weekly pattern',
      icon: Icons.date_range_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BarChart(
            values: averages,
            labels: kWeekdayShort,
            tooltips: [
              for (var i = 0; i < 7; i++) '${kWeekdayLong[i]}: ${formatAverage(averages[i])} per day',
            ],
            highlight: busiest,
            height: 90,
          ),
        ],
      ),
    );
  }

  Widget _buildDataSection(BuildContext context) {
    return  Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmClearHistory(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: _danger,
                side: const BorderSide(color: _danger),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(Icons.delete_outline, size: context.icon(20)),
              label: const Text('Delete review history'),
            ),
          ),
        ],
    );
  }

  Future<void> _confirmClearHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete review history'),
        content: const Text(
          'This permanently deletes every recorded review, which clears the '
          'heatmap and the statistics based on it.\n\n'
          'Your questions and their review schedule are kept. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: _danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await RevlogDao().deleteAll();
      Home.packagesChanged.value++;
      await _load();
      messenger.showSnackBar(const SnackBar(content: Text('Review history deleted.')));
    } catch (e) {
      debugPrint('Erro ao apagar o histórico de revisões: $e');
      messenger.showSnackBar(SnackBar(content: Text('Could not delete the history: $e')));
    }
  }
}
