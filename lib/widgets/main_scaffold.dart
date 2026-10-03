import 'package:flutter/material.dart';
import '../styles/app_theme.dart';
import '../styles/text_styles.dart';

import '../screens/setting_screen.dart';
import '../screens/package_edit_screen.dart';
import '../screens/questions_edit_screen.dart';
import '../screens/templaate_edit_screen.dart';
import '../screens/question_bank_screen.dart';
import '../screens/session_edit_screen.dart';
import 'new_tag_dialog.dart';

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
        await showNewTagDialog(context);
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

  /// Barra inferior com recorte para o FAB central.
  ///
  /// Não usa `BottomAppBar(shape: CircularNotchedRectangle())` de propósito:
  /// o clipper dele lê `Scaffold.geometryOf()`, que só pode ser lido durante o
  /// paint. Com a Home coberta por outra rota, o mouse (desktop) faz hit-test
  /// nela fora do paint e estoura a asserção. Como o FAB é sempre
  /// `centerDocked`, o recorte é fixo e dispensa a geometria do Scaffold.
  Widget _buildBottomBar() {
    return PhysicalShape(
      clipper: const _CenterNotchClipper(),
      color: context.colors.surface,
      elevation: 8,
      shadowColor: Colors.black,
      child: SafeArea(
        top: false,
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
                Navigator.pop(context); // fecha o drawer
                // Volta para a Home que já existe (primeira rota) em vez de
                // empilhar outra, e garante que a aba aberta seja a Home.
                Navigator.of(context).popUntil((route) => route.isFirst);
                widget.onTap?.call(0);
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
      bottomNavigationBar: _buildBottomBar(),
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

/// Recorte circular no topo-centro da barra, igual ao do FAB `centerDocked`
/// (FAB de 56 px com margem de 8 px, centro na borda superior da barra).
class _CenterNotchClipper extends CustomClipper<Path> {
  const _CenterNotchClipper();

  @override
  Path getClip(Size size) {
    final fab = Rect.fromCenter(
      center: Offset(size.width / 2, 0),
      width: 56,
      height: 56,
    ).inflate(8);
    return const CircularNotchedRectangle().getOuterPath(Offset.zero & size, fab);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
