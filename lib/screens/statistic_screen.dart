import 'package:flutter/material.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
            onPressed: () => Navigator.pop(context),
          ),
        title: const Text('Statistics',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E))),
      ),
      body: const Center(
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
      ),
    );
  }
}