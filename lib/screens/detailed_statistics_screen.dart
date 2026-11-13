import 'package:flutter/material.dart';

import '../data/DAO/revlog_dao.dart';
import '../data/stats/review_stats.dart';
import '../l10n/strings.dart';
import '../styles/app_theme.dart';
import '../widgets/period_chart_card.dart';
import '../widgets/stats_widgets.dart';
import '../widgets/responsive_columns.dart';
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
          context.tr('stats.detailedTitle'),
          style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: SafeArea(
        top: false, 
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
                : Text(context.tr('stats.loadFailedWith', {'error': _error!}),
                    textAlign: TextAlign.center, style: TextStyle(color: c.mutedText)),
          ),
        ),
      ];
    }

    if (stats.isEmpty) {
      return [
        StatCard(
          title: context.tr('stats.noReviews'),
          icon: Icons.insights_outlined,
          child: Text(
            context.tr('stats.noReviewsHint'),
            style: TextStyle(fontSize: 13, color: c.mutedText),
          ),
        ),
      ];
    }

    return [
        ResponsiveColumns(children: [
        _overview(stats),
        _recentActivity(context, stats),
        PeriodChartCard(stats: stats),
        _streaks(stats),
        _records(stats),
      ]),
    ];
  }

  Widget _overview(ReviewStats s) {
    return StatCard(
      title: context.tr('stats.overview'),
      child: StatGrid(children: [
        StatTile(label: context.tr('stats.totalReviews'), value: formatCount(s.total), outlined: true),
        StatTile(
          label: context.tr('stats.daysStudied'),
          value: formatCount(s.daysStudied),
          caption: s.firstDay == null ? null : context.tr('stats.since', {'date': formatDay(s.firstDay!)}),
          outlined: true,
        ),
        StatTile(
          label: context.tr('stats.avgStudyDay'),
          value: formatAverage(s.avgPerStudiedDay),
          caption: context.tr('stats.reviews'),
          outlined: true,
        ),
        StatTile(
          label: context.tr('stats.avgDay'),
          value: formatAverage(s.avgPerDay),
          caption: context.tr('stats.countingDaysOff'),
          outlined: true,
        ),
      ]),
    );
  }

  Widget _recentActivity(BuildContext context, ReviewStats s) {
    final c = context.colors;
    return StatCard(
      title: context.tr('stats.recent'),
      child: Column(
        children: [
          PeriodRow(label: context.tr('stats.today'), value: s.reviewsToday, previous: s.reviewsYesterday),
          PeriodRow(label: context.tr('stats.last7'), value: s.last7, previous: s.previous7),
          PeriodRow(label: context.tr('stats.last30'), value: s.last30, previous: s.previous30),
          PeriodRow(label: context.tr('stats.last365'), value: s.last365, previous: s.previous365),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.tr('stats.arrowsHint'),
              style: TextStyle(fontSize: 11, color: c.mutedText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _streaks(ReviewStats s) {
    final current = s.currentStreak;
    final longest = s.longestStreak;
    String pct(int n, int of) => context.tr('stats.nOfDays', {'n': n, 'of': of, 'pct': (n / of * 100).round()});
    return StatCard(
      title: context.tr('stats.streaks'),
      child: Column(
        children: [
          StatRow(context.tr('stats.currentStreak'), formatDays(current.length)),
          if (current.start != null)
            StatRow(context.tr('stats.currentSince'), formatDay(current.start!)),
          StatRow(context.tr('stats.longestStreak'), formatDays(longest.length)),
          if (longest.start != null && longest.end != null)
            StatRow(context.tr('stats.longestPeriod'),
              longest.length == 1
                  ? formatDay(longest.start!)
                  : '${formatDayShort(longest.start!)} – ${formatDay(longest.end!)}'),
          StatRow(context.tr('stats.studied30'), pct(s.daysStudiedIn(30), 30)),
          StatRow(context.tr('stats.studied90'), pct(s.daysStudiedIn(90), 90)),
        ],
      ),
    );
  }

  Widget _records(ReviewStats s) {
    final day = s.bestDay;
    final week = s.bestWeek;
    final month = s.bestMonth;
    return StatCard(
      title: context.tr('stats.records'),
      child: Column(
        children: [
          if (day != null) StatRow(context.tr('stats.bestDay'), '${formatCount(day.count)} · ${formatDay(day.start)}'),
          if (week != null)
            StatRow(context.tr('stats.bestWeek'), '${formatCount(week.count)} · ${context.tr('stats.weekOf', {'date': formatDayShort(week.start)})}'),
          if (month != null)
            StatRow(context.tr('stats.bestMonth'), '${formatCount(month.count)} · ${formatMonth(month.start)}'),
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
              label: Text(context.tr('stats.deleteHistory')),
            ),
          ),
        ],
    );
  }

  Future<void> _confirmClearHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('stats.deleteHistory')),
        content: Text(context.tr('stats.deleteHistoryBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('common.delete'), style: const TextStyle(color: _danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final t = context.tr;
    try {
      await RevlogDao().deleteAll();
      Home.packagesChanged.value++;
      await _load();
      messenger.showSnackBar(SnackBar(content: Text(t('stats.historyDeleted'))));
    } catch (e) {
      debugPrint('Erro ao apagar o histórico de revisões: $e');
      messenger.showSnackBar(SnackBar(content: Text(t('stats.historyDeleteFailed', {'error': e}))));
    }
  }
}
