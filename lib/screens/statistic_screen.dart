import 'package:flutter/material.dart';

import '../styles/app_theme.dart';

/// Aba de estatísticas da Home: resumo breve e rápido.
/// As análises completas ficam em DetailedStatisticsScreen (menu lateral).
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_outlined, size: context.icon(64), color: c.border),
          const SizedBox(height: 12),
          Text('No data yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.text)),
          const SizedBox(height: 4),
          Text('Start studying to see your statistics here.',
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ],
      ),
    );
  }
}
