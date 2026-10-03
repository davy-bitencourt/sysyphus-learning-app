import 'package:flutter/material.dart';

import '../data/DAO/revlog_dao.dart';
import '../styles/app_theme.dart';
import 'home.dart';

/// Estatísticas profundas e detalhadas, acessadas pelo menu lateral.
///
/// A aba de estatísticas da Home fica para o resumo rápido; aqui entram as
/// análises completas. Por enquanto as seções são placeholders (cada uma vira
/// um gráfico/tabela real depois), mas o bloco "Data" no fim já funciona.
class DetailedStatisticsScreen extends StatelessWidget {
  const DetailedStatisticsScreen({super.key});

  // Seções planejadas. Para implementar uma, troque o card por um widget real.
  static const List<_StatSection> _sections = [
    _StatSection(
      Icons.insights_outlined,
      'Overview',
      'Total reviews, questions studied, overall accuracy and study time.',
    ),
    _StatSection(
      Icons.show_chart,
      'Activity over time',
      'Reviews per day, week and month, with trends and best streaks.',
    ),
    _StatSection(
      Icons.track_changes_outlined,
      'Accuracy',
      'Hits and misses by package, tag and template.',
    ),
    _StatSection(
      Icons.event_note_outlined,
      'Review forecast',
      'How many questions are due over the next days and weeks.',
    ),
    _StatSection(
      Icons.psychology_outlined,
      'Retention',
      'How well you remember, grouped by how mature each question is.',
    ),
    _StatSection(
      Icons.timer_outlined,
      'Sessions',
      'Time, questions answered and results for each study session.',
    ),
  ];

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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'In-depth analysis of your studying. The quick summary stays on the '
            'Statistics tab of the Home screen.',
            style: TextStyle(fontSize: 13, color: c.mutedText),
          ),
          const SizedBox(height: 16),
          for (final section in _sections) _buildSectionCard(context, section),
          const SizedBox(height: 16),
          _buildDataSection(context),
        ],
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, _StatSection section) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(section.icon, size: context.icon(24), color: c.accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.text),
                ),
                const SizedBox(height: 4),
                Text(
                  section.description,
                  style: TextStyle(fontSize: 12, color: c.mutedText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Coming soon', style: TextStyle(fontSize: 10, color: c.mutedText)),
          ),
        ],
      ),
    );
  }

  /// Gestão dos dados de estatística (esta parte já funciona).
  Widget _buildDataSection(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Data',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.text),
          ),
          const SizedBox(height: 4),
          Text(
            'Deleting the review history clears the heatmap and every statistic '
            'built from it. Your questions and their review schedule are kept.',
            style: TextStyle(fontSize: 12, color: c.mutedText),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmClearHistory(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC62828),
                side: const BorderSide(color: Color(0xFFC62828)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(Icons.delete_outline, size: context.icon(20)),
              label: const Text('Delete review history'),
            ),
          ),
        ],
      ),
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
            child: const Text('Delete', style: TextStyle(color: Color(0xFFC62828))),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await RevlogDao().deleteAll();
      // A Home recarrega quando esse aviso muda (heatmap e contagens).
      Home.packagesChanged.value++;
      messenger.showSnackBar(const SnackBar(content: Text('Review history deleted.')));
    } catch (e) {
      debugPrint('Erro ao apagar o histórico de revisões: $e');
      messenger.showSnackBar(SnackBar(content: Text('Could not delete the history: $e')));
    }
  }
}

class _StatSection {
  final IconData icon;
  final String title;
  final String description;
  const _StatSection(this.icon, this.title, this.description);
}
