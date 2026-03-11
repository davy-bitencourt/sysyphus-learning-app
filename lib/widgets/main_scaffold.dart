
import 'package:flutter/material.dart';
import '../styles/text_styles.dart';

import '../screens/setting_screen.dart';
import '../screens/statistic_screen.dart';
import '../screens/home.dart';

class MainScaffold extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  const MainScaffold({
    super.key,
    required this.title,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation
    });


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
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const StatisticsScreen()));

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
    );
}
    

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}