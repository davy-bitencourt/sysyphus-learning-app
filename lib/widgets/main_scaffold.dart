import 'package:flutter/material.dart';
import '../styles/app_theme.dart';
import '../styles/text_styles.dart';

import '../screens/setting_screen.dart';
import '../screens/home.dart';
import '../screens/package_edit_screen.dart';
import '../screens/questions_edit_screen.dart';
import '../screens/templaate_edit_screen.dart';
import '../screens/question_bank_screen.dart';
import '../screens/session_edit_screen.dart';
import '../data/DAO/tag_dao.dart';

class MainScaffold extends StatefulWidget {
  final String title;
  final Widget body;
  final int currentIndex;
  final ValueChanged<int>? onTap;
  final VoidCallback? onStatisticsTap;
  final VoidCallback? onItemCreated;

  const MainScaffold({
    super.key,
    required this.title,
    required this.body,
    this.currentIndex = 0,
    this.onTap,
    this.onStatisticsTap,
    this.onItemCreated,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  OverlayEntry? _overlayEntry;
  bool _isMenuOpen = false;

  void _toggleMenu() {
    if (_isMenuOpen) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isMenuOpen = true);
  }

  void _closeMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() => _isMenuOpen = false);
    }
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Fundo semi-transparente para fechar o menu ao clicar fora
          GestureDetector(
            onTap: _closeMenu,
            behavior: HitTestBehavior.translucent,
            child: Container(
              color: Colors.black.withValues(alpha: 0.2),
            ),
          ),
          // Menu Flutuante posicionado acima do BottomAppBar / FAB central
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                color: context.colors.surface,
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _menuItem(Icons.folder_outlined, 'Novo pacote', 'package'),
                      _menuItem(Icons.quiz_outlined, 'Nova questão', 'question'),
                      _menuItem(Icons.dashboard_customize_outlined, 'Novo template', 'template'),
                      _menuItem(Icons.label_outline, 'Nova tag', 'tag'),
                      _menuItem(Icons.timer_outlined, 'Nova sessão', 'session'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, String action) {
    return InkWell(
      onTap: () {
        _closeMenu();
        _handleCreateAction(action);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: context.colors.accent, size: context.icon(20)),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: context.colors.text,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCreateAction(String action) async {
    switch (action) {
      case 'package':
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PackageEditScreen()),
        );
        if (result == true) widget.onItemCreated?.call();
        break;

      case 'question':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const QuestionsEditScreen()),
        );
        widget.onItemCreated?.call();
        break;

      case 'template':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TemplateEditScreen()),
        );
        widget.onItemCreated?.call();
        break;

      case 'tag':
        await _showQuickTextDialog(
          title: 'Nova tag',
          hint: 'Nome da tag',
          onConfirm: (text) => TagDao().insert(text),
        );
        widget.onItemCreated?.call();
        break;

      case 'session':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SessionEditScreen()),
        );
        widget.onItemCreated?.call();
        break;
    }
  }

  Future<void> _showQuickTextDialog({
    required String title,
    required String hint,
    required Future<void> Function(String text) onConfirm,
  }) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    final text = controller.text.trim();
    if (confirmed == true && text.isNotEmpty) {
      await onConfirm(text);
    }
  }

  // Só o ícone (o rótulo vira tooltip, para acessibilidade).
  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = widget.currentIndex == index;
    return Tooltip(
      message: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onTap?.call(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Icon(icon,
            color: isActive ? context.colors.accent : Colors.grey[400], size: context.icon(28)),
        ),
      ),
    );
  }

  Widget _drawerItem(BuildContext context, IconData icon, String label, {
    bool active = false,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon,
        color: active ? context.colors.accent : context.colors.text, size: context.icon(21)),
      title: Text(label,
        style: TextStyle(
          color: active ? context.colors.accent : context.colors.text,
          fontSize: 14,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
        )),
      tileColor: active ? context.colors.accent.withValues(alpha: 0.10) : Colors.transparent,
      onTap: onTap ?? () => Navigator.pop(context),
    );
  }

  @override
  void dispose() {
    _closeMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      appBar: AppBar(
        backgroundColor: context.colors.bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Builder(
                builder: (ctx) => IconButton(
                  icon: Icon(Icons.menu, color: context.colors.mutedText),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
              const SizedBox(width: 10),
              const Text('Sysyphus', style: bigText),
            ]),
            IconButton(
              icon: Icon(Icons.sync, color: context.colors.mutedText),
              onPressed: () {},
            ),
          ],
        ),
      ),
      drawer: Drawer(
        width: 240,
        backgroundColor: context.colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: SafeArea(
          child: Column(
            children: [
              _drawerItem(context, Icons.list, 'Home', active: true, onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const Home()));
              }),
              _drawerItem(context, Icons.chrome_reader_mode, 'Database', onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const QuestionBankScreen()));
              }),
              _drawerItem(context, Icons.bar_chart, 'Statistics', onTap: () {
                Navigator.pop(context);
                widget.onStatisticsTap?.call();
              }),
              Divider(color: context.colors.border, thickness: 1, indent: 16, endIndent: 16),
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
      body: widget.body,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: context.colors.surface,
        surfaceTintColor: Colors.transparent,
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
        onPressed: _toggleMenu,
        backgroundColor: context.colors.accent,
        elevation: 0,
        shape: const CircleBorder(),
        child: AnimatedRotation(
          turns: _isMenuOpen ? 0.125 : 0, // Rotaciona o ícone de + suavemente quando aberto
          duration: const Duration(milliseconds: 200),
          child: Icon(
            Icons.add,
            color: Colors.white,
            size: context.icon(28),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}