import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  final List<Map<String, dynamic>> _settings = const [
    {'icon': Icons.settings,        'title': 'General',       'sub': 'Language • Studying • System-wide'},
    {'icon': Icons.school,          'title': 'New study screen', 'sub': 'Screen • Toolbar • Answer buttons'},
    {'icon': Icons.rate_review,     'title': 'Reviewing',     'sub': 'Scheduling • Keep screen on'},
    {'icon': Icons.sync,            'title': 'Sync',          'sub': 'Account • Automatic synchronization'},
    {'icon': Icons.notifications,   'title': 'Notifications', 'sub': 'Notify when • Vibrate • Blink light'},
    {'icon': Icons.palette,         'title': 'Appearance',    'sub': 'Themes • Background'},
    {'icon': Icons.tune,            'title': 'Controls',      'sub': 'Gestures • Keyboard • Bluetooth'},
    {'icon': Icons.accessibility,   'title': 'Accessibility', 'sub': 'Card zoom • Answer button size'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Settings',
          style: TextStyle(color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [

          // barra de busca
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // lista de itens
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: List.generate(_settings.length, (i) {
                final item = _settings[i];
                final isLast = i == _settings.length - 1;
                return Column(
                  children: [
                    ListTile(
                      leading: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(item['icon'] as IconData,
                          size: 18, color: const Color(0xFF1A1A2E)),
                      ),
                      title: Text(item['title'] as String,
                        style: const TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
                      subtitle: Text(item['sub'] as String,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                      onTap: () {},
                    ),
                    if (!isLast)
                      Divider(height: 1, indent: 16, color: Colors.grey[200]),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}