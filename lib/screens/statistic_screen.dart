import 'package:flutter/material.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_outlined, size: 64, color: Color(0xFFE0E0E0)),
          SizedBox(height: 12),
          Text('No data yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E))),
          SizedBox(height: 4),
          Text('Start studying to see your statistics here.',
            style: TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }
}