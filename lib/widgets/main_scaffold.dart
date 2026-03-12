
import 'package:flutter/material.dart';
import '../styles/text_styles.dart';

import '../screens/setting_screen.dart';
import '../screens/home.dart';

class MainScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final int currentIndex;        // ← adiciona
  final ValueChanged<int>? onTap; // ← adiciona
  final VoidCallback? onStatisticsTap;

  const MainScaffold({
    super.key,
    required this.title,
    required this.body,
    this.currentIndex = 0,
    this.onTap,
    this.onStatisticsTap
    });


  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap?.call(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
            color: isActive ? const Color(0xFFFF8F00) : Colors.grey[400], size: 24),
          Text(label,
            style: TextStyle(fontSize: 11,
              color: isActive ? const Color(0xFFFF8F00) : Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _drawerItem(BuildContext context, IconData icon, String label, {
    bool active = false,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon,
        color: active ? const Color(0xFFFFB300) : const Color(0xFF1A1A2E), size: 21),
      title: Text(label,
        style: TextStyle(
          color: active ? const Color(0xFFFFB300) : const Color(0xFF1A1A2E),
          fontSize: 14,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
        )),
      tileColor: active ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
      onTap: onTap ?? () => Navigator.pop(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu, color: Color(0xFF555555)),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
              
              const SizedBox(width: 10),
  
              const Text('Sysyphus', style: bigText),
  
            ]),
  
            IconButton(
              icon: const Icon(Icons.sync, color: Color(0xFF555555)),
              onPressed: () {},
            ),
          ],
        ),
      ),
      drawer: Drawer(
        width: 240,
        backgroundColor: const Color(0xFFFFFFFF),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          child: SafeArea(
            child: Column(
              children: [
                _drawerItem(context, Icons.list, 'Home', active: true, onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const Home()));
                }),
                _drawerItem(context, Icons.chrome_reader_mode, 'Questions finder'),

                _drawerItem(context, Icons.bar_chart, 'Statistics', onTap: () {
                  Navigator.pop(context);
                  onStatisticsTap?.call();
                }),

                const Divider(color: Color(0xFFE0E0E0), thickness: 1, indent: 16, endIndent: 16),

                _drawerItem(context, Icons.settings, 'Settings', onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                }),

                _drawerItem(context, Icons.help_outline, 'Help', onTap: () {}),
                _drawerItem(context, Icons.sports_soccer, 'Support', onTap: () {}),
              ],
            ),
          ),
      ),
      body: body,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        elevation: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_outlined, 'Home', 0),
              const SizedBox(width: 48),
              _buildNavItem(Icons.bar_chart_outlined, 'Statistics', 1),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFFE65100),
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
}
}